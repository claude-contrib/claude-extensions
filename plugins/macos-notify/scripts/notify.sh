#!/usr/bin/env bash
#
# notify.sh - macOS Notification Center hook for Claude Code
#
# DESCRIPTION:
#   Sends native macOS Notification Center alerts when Claude Code completes
#   a task or needs attention. Uses terminal-notifier for click-to-focus
#   support via focus.sh.
#
# DEPENDENCY:
#   terminal-notifier (brew install terminal-notifier)
#
# USAGE:
#   Invoked automatically by Claude Code hooks on Stop and Notification events.
#
# TMUX OPTIONS (set via tmux set-option -g <option> <value>):
#   @claude-notify-term-program  ghostty  - Terminal identifier (e.g. "ghostty", "iTerm.app").
#                                           Required when running inside tmux, where $TERM_PROGRAM
#                                           is "tmux" rather than the outer terminal app.
#   @claude-notify-sound         on       - Play a sound with the notification
#
# STDIN (JSON from Claude Code):
#   hook_event_name  - "Stop" or "Notification"
#
# EXIT CODES:
#   0 - Success (including graceful no-op on non-macOS)
#   Non-zero - Notification command error

set -euo pipefail
[ -z "${DEBUG:-}" ] || set -x

# Read tmux option with fallback default
_tmux_option() {
	local option="$1"
	local default="$2"
	local value
	value="$(tmux show-option -gv "$option" 2>/dev/null || true)"
	if [[ -z "$value" ]]; then
		echo "$default"
	else
		echo "$value"
	fi
}

# Extract a string field from JSON
_json_field() {
	local field="$1"
	local json="$2"
	if command -v jq &>/dev/null; then
		printf '%s' "$json" | jq -r --arg f "$field" '.[$f] // empty'
	else
		printf '%s' "$json" | sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
	fi
}

# Prints the session name of Claude's pane
_tmux_session_name() {
	tmux display-message -p -t "${TMUX_PANE}" "#{session_name}" 2>/dev/null || true
}

# Prints the unique window ID of Claude's pane (e.g. @4).
# Using the window ID avoids ambiguity when the window name contains dots,
# which tmux otherwise interprets as the window-pane separator in target strings.
_tmux_window_id() {
	tmux display-message -p -t "${TMUX_PANE}" "#{window_id}" 2>/dev/null || true
}

# Prints the TTY of the current tmux client
_tmux_client_tty() {
	tmux display-message -p "#{client_tty}" 2>/dev/null || true
}

# Returns 0 if sound is enabled
_sound_enabled() {
	[[ "$(_tmux_option "@claude-notify-sound" "on")" == "on" ]]
}

# Get the project name from the working directory.
#
# Returns owner/repo parsed from the origin remote URL when available,
# falls back to the git root basename, then $PWD basename.
_project_name() {
	local git_root remote owner_repo
	git_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"

	if [[ -n "$git_root" ]]; then
		remote="$(git remote get-url origin 2>/dev/null || true)"
		if [[ -n "$remote" ]]; then
			owner_repo="$(printf '%s' "$remote" | sed -E 's#.*[:/]([^/]+/[^/]+)$#\1#' | sed 's/\.git$//')"
			if [[ -n "$owner_repo" ]]; then
				echo "$owner_repo"
				return
			fi
		fi
		basename "$git_root"
	else
		basename "$PWD"
	fi
}

# Get the current git branch, or empty string if not in a git repo
_git_branch() {
	git rev-parse --abbrev-ref HEAD 2>/dev/null || true
}

# Prints the scripts directory (works with or without CLAUDE_PLUGIN_ROOT)
_scripts_dir() {
	if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
		echo "${CLAUDE_PLUGIN_ROOT}/scripts"
	else
		cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
	fi
}

# Send a macOS Notification Center alert via terminal-notifier.
#
# Clicking the notification runs focus.sh to bring the terminal to the front.
#
# Args:
#   $1 - Title (project name)
#   $2 - Subtitle (action — branch)
#   $3 - Sound name (e.g. "Glass", "Ping"), or empty to omit sound
#   $4 - tmux session name (optional)
#   $5 - tmux window id    (optional, e.g. @4)
#   $6 - tmux client tty   (optional)
_send_notification() {
	local title="$1"
	local subtitle="$2"
	local sound="$3"
	local tmux_session="${4:-}"
	local tmux_window="${5:-}"
	local tmux_client="${6:-}"

	local scripts_dir
	scripts_dir="$(_scripts_dir)"

	local tmux_bin
	tmux_bin="$(command -v tmux 2>/dev/null || true)"

	local focus_command
	printf -v focus_command '%q ' "${scripts_dir}/focus.sh" "$tmux_bin" "$tmux_session" "$tmux_window" "$tmux_client"
	focus_command="${focus_command% }"

	local notify_args=(-title "$title" -subtitle "$subtitle" -message " " -group "claude-code" -execute "$focus_command")
	if [[ -n "$sound" ]]; then
		notify_args+=(-sound "$sound")
	fi

	terminal-notifier "${notify_args[@]}"
}

# Handle a Stop or Notification event
_handle_event() {
	local event="$1"
	local project="$2"
	local branch="$3"
	local tmux_session="$4"
	local tmux_window="$5"
	local tmux_client="$6"

	local subtitle sound
	case "$event" in
	Stop)
		subtitle="Task complete"
		sound="Glass"
		;;
	Notification)
		subtitle="Needs your input"
		sound="Ping"
		;;
	esac

	if [[ -n "$branch" ]]; then subtitle="${subtitle} — ${branch}"; fi
	if ! _sound_enabled; then sound=""; fi

	_send_notification "$project" "$subtitle" "$sound" "$tmux_session" "$tmux_window" "$tmux_client"
}

# Main entry point
main() {
	if [[ "$(uname -s)" != "Darwin" ]]; then
		exit 0
	fi

	if ! command -v terminal-notifier &>/dev/null; then
		echo "macos-notify: terminal-notifier not found. Install with: brew install terminal-notifier" >&2
		exit 1
	fi

	local event_args
	event_args="$(cat)"

	local event_name
	event_name="$(_json_field "hook_event_name" "$event_args")"

	local project
	project="$(_project_name)"

	local branch
	branch="$(_git_branch)"

	local tmux_session="" tmux_window="" tmux_client=""
	if [[ -n "${TMUX:-}" ]] && [[ -n "${TMUX_PANE:-}" ]]; then
		tmux_session="$(_tmux_session_name)"
		tmux_window="$(_tmux_window_id)"
		tmux_client="$(_tmux_client_tty)"
	fi

	case "$event_name" in
	Stop | Notification)
		_handle_event "$event_name" "$project" "$branch" "$tmux_session" "$tmux_window" "$tmux_client"
		;;
	esac
}

main "$@"
