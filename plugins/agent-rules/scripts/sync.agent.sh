#!/usr/bin/env bash
#
# sync.sh - AGENTS.md to Claude Code Path-Specific Rules Sync
#
# DESCRIPTION:
#   Automatically discovers AGENTS.md files in a repository and converts them
#   to Claude Code's path-specific rules format. Each AGENTS.md file is transformed
#   with YAML frontmatter that specifies which paths the rules apply to.
#
# USAGE:
#   bash sync.sh
#
# BEHAVIOR:
#   1. Finds repository root (git) or uses current directory
#   2. Discovers all AGENTS.md files (respects .gitignore in git repos)
#   3. Transforms each file:
#      - Adds YAML frontmatter with path patterns
#      - Preserves original content
#      - Writes to .claude/rules/agents/ with mirrored directory structure
#      - Skips writing if content is unchanged (idempotent on repeated runs)
#   4. Removes rule files whose source AGENTS.md no longer exists (orphan cleanup)
#   5. Prunes empty directories left behind by orphan removal
#
# EXAMPLES:
#   Input:  /repo/AGENTS.md
#   Output: /repo/.claude/rules/agents/AGENTS.md (applies to **/* pattern)
#
#   Input:  /repo/src/api/AGENTS.md
#   Output: /repo/.claude/rules/agents/src/api/AGENTS.md (applies to src/api/**/* pattern)
#
# ENVIRONMENT:
#   DEBUG - Set to enable bash tracing (set -x)
#
# EXIT CODES:
#   0 - Success
#   Non-zero - Error (script uses set -e for strict error handling)
#
# DESIGNED FOR:
#   Claude Code SessionStart hook (runs silently on every session start)

[ -z "${DEBUG:-}" ] || set -x

set -euo pipefail

# Get the working directory (git repository root or current directory)
GIT_REPOSITORY_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
# Get the Claude rules directory
CLAUDE_RULES_DIR="$GIT_REPOSITORY_DIR/.claude/rules/agents"

# Calculate relative path from repository root
#
# Args:
#   $1 - Absolute path to an AGENTS.md file
#
# Returns:
#   Prints the relative directory path from repository root
#   Returns "." if file is in repository root
#
# Example:
#   _get_relative_dir "/repo/src/api/AGENTS.md" -> "src/api"
#   _get_relative_dir "/repo/AGENTS.md" -> "."
_get_relative_dir() {
	local file_path="$1"
	local dir_path

	# Get directory containing the file
	dir_path="$(dirname "$file_path")"

	# Calculate relative path from repository root
	if [[ "${dir_path}" == "$GIT_REPOSITORY_DIR" ]]; then
		# AGENTS.md is in repository root
		echo "."
	else
		# Remove repository root prefix and leading slash
		echo "${dir_path#"$GIT_REPOSITORY_DIR"/}"
	fi
}

# Generate YAML frontmatter for path-specific rules
#
# Creates the YAML frontmatter block with path patterns for Claude Code rules.
# Root directory files get "**/*" pattern, subdirectories get "<dir>/**/*" pattern.
#
# Args:
#   $1 - Relative directory path ("." for root, or "src/api" for subdirectories)
#
# Returns:
#   Prints YAML frontmatter block with trailing blank line
#
# Example:
#   _generate_rule_file_header "src/api" outputs:
#   ---
#   paths:
#     - "src/api/**/*"
#   ---
#
_generate_rule_file_header() {
	local relative_dir="$1"
	local path_pattern

	if [[ "$relative_dir" == "." ]]; then
		# Root directory - match everything
		path_pattern="**/*"
	else
		# Specific directory - match directory and all subdirectories
		path_pattern="$relative_dir/**/*"
	fi

	cat <<EOF
---
paths:
  - "${path_pattern}"
---
EOF
}

# Generate Claude Code Rule File
#
# Combines YAML frontmatter header with the original AGENTS.md content and writes
# to the target file. Ensures proper spacing between header and body.
#
# Args:
#   $1 - Target file path where the rule file will be written
#   $2 - YAML frontmatter header (from _generate_rule_file_header)
#   $3 - Original AGENTS.md file content
#
# Side Effects:
#   Creates or overwrites the target file
#
# Note:
#   Command substitution strips trailing newlines, so we add them back with printf "%s\n\n"
_write_rule_file() {
	local target_file="$1"
	local target_file_header="$2"
	local target_file_body="$3"
	{
		printf "%s\n\n" "$target_file_header"
		printf "%s" "$target_file_body"
	} >"$target_file"
}

# Create a Claude Code rule file from an AGENTS.md source file
#
# Main function that orchestrates the transformation of an AGENTS.md file into
# a Claude Code path-specific rule. Creates necessary directories, calculates
# paths, generates frontmatter, and writes the final rule file.
#
# Skips writing if the target already contains identical content (avoids
# unnecessary I/O on every SessionStart when files haven't changed).
#
# Args:
#   $1 - Absolute path to the source AGENTS.md file
#
# Output:
#   Prints the absolute path of the target rule file (used by main for orphan
#   detection).
#
# Side Effects:
#   Creates directory structure under .claude/rules/agents/
#   Creates or updates the transformed AGENTS.md file with YAML frontmatter
#
# Example:
#   _create_rule_file "/repo/src/api/AGENTS.md"
#   Creates: /repo/.claude/rules/agents/src/api/AGENTS.md
_create_rule_file() {
	local source_file="$1"

	local relative_dir
	relative_dir="$(_get_relative_dir "$source_file")"

	local target_dir
	# Create target directory structure
	if [[ "$relative_dir" == "." ]]; then
		target_dir="$CLAUDE_RULES_DIR"
	else
		target_dir="$CLAUDE_RULES_DIR/$relative_dir"
	fi

	mkdir -p "$target_dir"

	local target_file
	target_file="$target_dir/AGENTS.md"

	# Generate file header
	local rule_header
	rule_header="$(_generate_rule_file_header "$relative_dir")"

	# Generate file body
	local rule_body
	rule_body="$(cat "$source_file")"

	# Write to a temp file then compare — skip if content is unchanged
	local tmp_file
	tmp_file="$(mktemp)"
	_write_rule_file "$tmp_file" "$rule_header" "$rule_body"

	if [[ -f "$target_file" ]] && cmp -s "$tmp_file" "$target_file"; then
		rm "$tmp_file"
	else
		mv "$tmp_file" "$target_file"
	fi

	echo "$target_file"
}

# Find AGENTS.md files using git ls-files (efficient, respects .gitignore)
#
# Uses git to efficiently find all AGENTS.md files in the repository, both tracked
# and untracked (but not ignored). This method respects .gitignore and is faster
# than filesystem traversal.
#
# Args:
#   $1 - Name of array variable to populate with results (passed by reference)
#
# Side Effects:
#   Populates the referenced array with absolute paths to AGENTS.md files
#   Excludes files in .claude/ directory
#
# Returns:
#   0 on success
#
# Example:
#   local files=()
#   _find_agents_files_git files
#   # files array now contains: ["/repo/AGENTS.md", "/repo/src/api/AGENTS.md", ...]
_find_agents_files_git() {
	# shellcheck disable=SC2178
	local -n agents_file_list_result=$1
	# Use git ls-files to efficiently find AGENTS.md files
	local git_file_list=()
	# This respects .gitignore and never traverses ignored directories
	mapfile -t -d '' git_file_list < <({
		# Get tracked AGENTS.md files
		git -C "$GIT_REPOSITORY_DIR" ls-files -z '*/AGENTS.md' 'AGENTS.md' 2>/dev/null || true
		# Get untracked AGENTS.md files (respecting .gitignore)
		git -C "$GIT_REPOSITORY_DIR" ls-files --others --exclude-standard -z '*/AGENTS.md' 'AGENTS.md' 2>/dev/null || true
	})

	# Filter out .claude directory and prepend repository path
	for file in "${git_file_list[@]}"; do
		if [[ "$file" != .claude/* && -n "$file" ]]; then
			agents_file_list_result+=("$GIT_REPOSITORY_DIR/$file")
		fi
	done
}

# Find AGENTS.md files using find (fallback for non-git directories)
#
# Fallback method for finding AGENTS.md files when not in a git repository.
# Uses filesystem traversal to locate all AGENTS.md files.
#
# Args:
#   $1 - Name of array variable to populate with results (passed by reference)
#
# Side Effects:
#   Populates the referenced array with absolute paths to AGENTS.md files
#   Excludes files in .claude/ directory
#
# Returns:
#   0 on success
#
# Note:
#   This method does not respect .gitignore and traverses all directories
#   (except .claude/), so it may be slower than the git-based approach.
#
# Example:
#   local files=()
#   _find_agents_files_find files
#   # files array now contains: ["/dir/AGENTS.md", "/dir/docs/AGENTS.md", ...]
_find_agents_files_find() {
	# shellcheck disable=SC2178
	local -n agents_file_list_result=$1
	# Find all AGENTS.md files (excluding .claude directory)
	while IFS= read -r -d '' file; do
		agents_file_list_result+=("$file")
	done < <(find "$GIT_REPOSITORY_DIR" -type f -name "AGENTS.md" -not -path "*/.claude/*" -print0)
}

# Main execution function
#
# Entry point of the script. Orchestrates the complete sync process:
# 1. Ensures the rules output directory exists
# 2. Detects if running in a git repository
# 3. Finds all AGENTS.md files (using git or find)
# 4. Transforms each file into a Claude Code rule (skipping unchanged files)
# 5. Removes orphaned rule files whose source AGENTS.md no longer exists
# 6. Prunes empty directories left behind by orphan removal
#
# Side Effects:
#   - Creates $CLAUDE_RULES_DIR if it does not exist
#   - Creates/updates transformed AGENTS.md files with YAML frontmatter
#   - Removes rule files that no longer have a corresponding source
#
# Environment Variables:
#   GIT_REPOSITORY_DIR - Set by script to repository root or pwd
#   CLAUDE_RULES_DIR - Set by script to .claude/rules/agents
#
# Exit Codes:
#   0 - Success
#   Non-zero - Error (via set -e)
main() {
	mkdir -p "$CLAUDE_RULES_DIR"

	local agents_file_list=()
	# Check if we're in a git repository
	if git -C "$GIT_REPOSITORY_DIR" rev-parse --git-dir >/dev/null 2>&1; then
		# Use git ls-files (efficient, respects .gitignore)
		_find_agents_files_git agents_file_list
	else
		# Fallback to find for non-git directories
		_find_agents_files_find agents_file_list
	fi

	# Process each source file; collect the target paths that should exist
	local processed_targets=()
	for agents_file in "${agents_file_list[@]}"; do
		processed_targets+=("$(_create_rule_file "$agents_file")")
	done

	# Remove orphaned target files (source AGENTS.md was deleted)
	while IFS= read -r -d '' existing_target; do
		local keep=0
		for t in "${processed_targets[@]}"; do
			[[ "$t" == "$existing_target" ]] && keep=1 && break
		done
		[[ $keep -eq 0 ]] && rm "$existing_target"
	done < <(find "$CLAUDE_RULES_DIR" -type f -name "AGENTS.md" -print0 2>/dev/null)

	# Prune empty directories left behind by orphan removal
	find "$CLAUDE_RULES_DIR" -mindepth 1 -type d -empty -delete 2>/dev/null || true
}

[[ "${BASH_SOURCE[0]}" != "${0}" ]] || main "$@"
