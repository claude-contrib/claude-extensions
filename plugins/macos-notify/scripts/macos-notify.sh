#!/usr/bin/env bash
#
# macos-notify.sh - macOS Notification Center hook for Claude Code
#
# DESCRIPTION:
#   Sends native macOS Notification Center alerts when Claude Code needs
#   attention. Uses terminal-notifier for click-to-focus support via
#   macos-focus.sh.
#
# DEPENDENCY:
#   terminal-notifier (brew install terminal-notifier)
#
# USAGE:
#   Invoked automatically by Claude Code hooks on Notification events.
#
# TMUX OPTIONS (set via tmux set-option -g <option> <value>):
#   @claude-notify-terminal  ghostty  - Terminal identifier (e.g. "ghostty", "iTerm.app").
#                                       Required when running inside tmux, where $TERM_PROGRAM
#                                       is "tmux" rather than the outer terminal app.
#   @claude-notify-sound     on        - Play a sound with the notification
#
# STDIN (JSON from Claude Code):
#   hook_event_name  - "Notification"
#
# EXIT CODES:
#   0 - Success (including graceful no-op on non-macOS)
#   Non-zero - Notification command error

set -euo pipefail
[ -z "${DEBUG:-}" ] || set -x

# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

# Read tmux option with fallback default
#
# Args:
#   $1 - Option name
#   $2 - Default value if option is not set
#
# Returns:
#   Prints the option value or default
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

# Extract a string field from the JSON event_args
#
# Uses jq when available, falls back to sed for environments without it.
#
# Args:
#   $1 - Field name
#   $2 - JSON event_args string
#
# Returns:
#   Prints the field value, or empty string if not present
_json_field() {
	local field="$1"
	local json="$2"
	if command -v jq &>/dev/null; then
		printf '%s' "$json" | jq -r --arg f "$field" '.[$f] // empty'
	else
		# jq not found — sed fallback is unreliable with escaped quotes,
		# newlines in values, or special characters. Install jq for robustness.
		[[ -z "${DEBUG:-}" ]] || echo "[macos-notify] WARNING: jq not found, using sed fallback for JSON parsing" >&2
		printf '%s' "$json" | sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
	fi
}

# Prints the scripts directory (works with or without CLAUDE_PLUGIN_ROOT)
_scripts_dir() {
	if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
		echo "${CLAUDE_PLUGIN_ROOT}/scripts"
	else
		cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
	fi
}

# ---------------------------------------------------------------------------
# tmux state readers
# ---------------------------------------------------------------------------

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

# Prints the currently active tmux session ID
_tmux_active_session_id() {
	tmux display-message -p "#{session_id}" 2>/dev/null || true
}

# Prints the currently active tmux window ID
_tmux_active_window_id() {
	tmux display-message -p "#{window_id}" 2>/dev/null || true
}

# Prints the session ID of Claude's pane
_tmux_pane_session_id() {
	tmux display-message -p -t "${TMUX_PANE}" "#{session_id}" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Config predicates
# ---------------------------------------------------------------------------

# Returns 0 if @claude-notify-sound is enabled
_tmux_sound_enabled() {
	[[ "$(_tmux_option "@claude-notify-sound" "on")" == "on" ]]
}

# ---------------------------------------------------------------------------
# State predicates
# ---------------------------------------------------------------------------

# Returns 0 if the active tmux session and window match Claude's pane.
_tmux_is_active_window() {
	[[ "$(_tmux_active_session_id)" == "$(_tmux_pane_session_id)" ]] &&
		[[ "$(_tmux_active_window_id)" == "$(_tmux_window_id)" ]]
}

# Returns 0 if the configured terminal app is the frontmost macOS application.
_macos_is_terminal_focused() {
	local term_program
	term_program="$(_tmux_option "@claude-notify-terminal" "ghostty")"

	local app_name
	case "$term_program" in
	Apple_Terminal) app_name="Terminal" ;;
	iTerm.app) app_name="iTerm2" ;;
	alacritty) app_name="Alacritty" ;;
	WezTerm) app_name="WezTerm" ;;
	kitty) app_name="kitty" ;;
	ghostty) app_name="Ghostty" ;;
	*) return 1 ;;
	esac

	local frontmost
	frontmost="$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null || true)"

	[[ "$frontmost" == "$app_name" ]]
}

# ---------------------------------------------------------------------------
# Project helpers
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# Notification actions
# ---------------------------------------------------------------------------

# Build the shell-quoted focus command string passed to terminal-notifier -execute.
#
# Reads tmux state directly from the environment. When not running inside tmux,
# session/window/client args are passed as empty strings so macos-focus.sh
# skips the tmux window switch and only activates the terminal app.
#
# Returns:
#   Prints the focus command string, ready for use as a -execute argument
_focus_command() {
	local tmux_session="" tmux_window="" tmux_client=""
	if [[ -n "${TMUX:-}" ]] && [[ -n "${TMUX_PANE:-}" ]]; then
		tmux_session="$(_tmux_session_name)"
		tmux_window="$(_tmux_window_id)"
		tmux_client="$(_tmux_client_tty)"
	fi

	local scripts_dir tmux_bin cmd
	scripts_dir="$(_scripts_dir)"
	tmux_bin="$(command -v tmux 2>/dev/null || true)"

	printf -v cmd '%q ' "${scripts_dir}/macos-focus.sh" "$tmux_bin" "$tmux_session" "$tmux_window" "$tmux_client"
	echo "${cmd% }"
}

# Send a macOS Notification Center alert via terminal-notifier.
#
# Clicking the notification runs macos-focus.sh to bring the terminal to the front.
#
# Args:
#   $1 - Title (project name)
#   $2 - Subtitle text (current git branch will be appended automatically)
#   $3 - Sound name (e.g. "Ping"), or empty to omit sound
_notify_alert() {
	local title="$1"
	local subtitle="$2"
	local sound="$3"

	local focus_command
	focus_command="$(_focus_command)"

	local git_branch
	git_branch="$(_git_branch)"

	if [[ -n "$git_branch" ]]; then
		subtitle="${subtitle} — ${git_branch}"
	fi

	local notify_args=(-title "$title" -subtitle "$subtitle" -message " " -group "claude-code" -execute "$focus_command")
	if [[ -n "$sound" ]]; then
		notify_args+=(-sound "$sound")
	fi

	terminal-notifier "${notify_args[@]}"
}

# ---------------------------------------------------------------------------
# Event handler
# ---------------------------------------------------------------------------

# Handle a Notification event
_handle_event() {
	if _macos_is_terminal_focused; then
		if [[ -z "${TMUX:-}" ]] || _tmux_is_active_window; then
			return 0
		fi
	fi

	local alert_title
	alert_title="$(_project_name)"

	local alert_subtitle="Claude needs your input"

	local alert_sound="Ping"
	if ! _tmux_sound_enabled; then
		alert_sound=""
	fi

	_notify_alert "$alert_title" "$alert_subtitle" "$alert_sound"
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

# Check runtime dependencies.
#
# Exits 0 silently on non-macOS (graceful no-op).
# Exits 1 with a message if terminal-notifier is not installed.
_check_dependencies() {
	if [[ "$(uname -s)" != "Darwin" ]]; then
		exit 0
	fi

	if ! command -v terminal-notifier &>/dev/null; then
		echo "macos-notify: terminal-notifier not found. Install with: brew install terminal-notifier" >&2
		exit 1
	fi
}

# Guards against non-macOS environments, checks for terminal-notifier,
# reads the event args from stdin, and dispatches to the event handler.
main() {
	_check_dependencies

	local event_args
	event_args="$(cat)"

	local event_name
	event_name="$(_json_field "hook_event_name" "$event_args")"

	case "$event_name" in
	Notification)
		_handle_event
		;;
	esac
}

main "$@"
