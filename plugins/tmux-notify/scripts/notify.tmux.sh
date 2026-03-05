#!/usr/bin/env bash
#
# notify.sh - tmux notification hook for Claude Code
#
# DESCRIPTION:
#   Sends notifications to the tmux pane running Claude Code when it completes
#   a task or needs attention. Supports three mechanisms: visual bell,
#   display-message, and auto-focus — all configurable via tmux session options.
#
# USAGE:
#   Invoked automatically by Claude Code hooks on Stop and Notification events.
#
# TMUX OPTIONS (set via tmux set-option -g <option> <value>):
#   @claude-notify-bell        on  - Write \a to the pane TTY (visual bell)
#   @claude-notify-message     off - Show display-message when Claude's window is inactive
#   @claude-notify-auto-focus  off - Switch focus to Claude's pane on completion
#
# STDIN (JSON from Claude Code):
#   hook_event_name        - "Stop" or "Notification"
#
# EXIT CODES:
#   0 - Success (including graceful no-op when not in tmux)
#   Non-zero - tmux command error

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
		[[ -z "${DEBUG:-}" ]] || echo "[tmux-notify] WARNING: jq not found, using sed fallback for JSON parsing" >&2
		printf '%s' "$json" | sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
	fi
}

# ---------------------------------------------------------------------------
# tmux state readers
# ---------------------------------------------------------------------------

# Prints the current tmux session ID
_tmux_current_session() {
	tmux display-message -p "#{session_id}"
}

# Prints the currently active tmux window ID
_tmux_active_window() {
	tmux display-message -p "#{window_id}"
}

# Prints the currently active tmux pane ID
_tmux_active_pane() {
	tmux display-message -p "#{pane_id}"
}

# Prints the TTY device path of Claude's pane
_tmux_pane_tty() {
	tmux display-message -p -t "${TMUX_PANE}" "#{pane_tty}"
}

# Prints the session ID of Claude's pane
_tmux_pane_session() {
	tmux display-message -p -t "${TMUX_PANE}" "#{session_id}"
}

# Prints the window ID of Claude's pane
_tmux_pane_window() {
	tmux display-message -p -t "${TMUX_PANE}" "#{window_id}"
}

# Prints the window name of Claude's pane
_tmux_pane_window_name() {
	tmux display-message -p -t "${TMUX_PANE}" "#{window_name}"
}

# ---------------------------------------------------------------------------
# Config predicates
# ---------------------------------------------------------------------------

# Returns 0 if @claude-notify-bell is enabled
_tmux_bell_enabled() {
	[[ "$(_tmux_option "@claude-notify-bell" "on")" == "on" ]]
}

# Returns 0 if @claude-notify-message is enabled
_tmux_message_enabled() {
	[[ "$(_tmux_option "@claude-notify-message" "off")" == "on" ]]
}

# Returns 0 if @claude-notify-auto-focus is enabled
_tmux_auto_focus_enabled() {
	[[ "$(_tmux_option "@claude-notify-auto-focus" "off")" == "on" ]]
}

# ---------------------------------------------------------------------------
# State predicates
# ---------------------------------------------------------------------------

# Returns 0 if Claude's pane is the currently active pane
_tmux_is_active_pane() {
	[[ "$(_tmux_active_pane)" == "${TMUX_PANE:-}" ]]
}

# Returns 0 if the current session is the same as Claude's pane session
_tmux_is_active_session() {
	[[ "$(_tmux_current_session)" == "$(_tmux_pane_session)" ]]
}

# ---------------------------------------------------------------------------
# Notification actions
# ---------------------------------------------------------------------------

# Write \a to the pane's TTY to trigger a visual/audible bell
_notify_bell() {
	if _tmux_bell_enabled; then
		printf '\a' >"$(_tmux_pane_tty)" || {
			[[ -z "${DEBUG:-}" ]] || echo "[tmux-notify] WARNING: failed to write bell to pane TTY" >&2
			true
		}
	fi
}

# Show a display-message when Claude's window is inactive
#
# Only fires when in the same session as Claude and a different window is active.
#
# Args:
#   $1 - Message text to show
_notify_message() {
	local text="$1"
	if _tmux_message_enabled; then
		if _tmux_is_active_session; then
			local active_window
			active_window="$(_tmux_active_window)"

			local claude_window
			claude_window="$(_tmux_pane_window)"

			if [[ "$active_window" != "$claude_window" ]]; then
				tmux display-message -l "$text"
			fi
		fi
	fi
}

# Switch focus to Claude's pane
#
# Selects Claude's pane within the current window. Only acts when
# @claude-notify-auto-focus is on and the pane is not already active.
# Uses a short delay to run after Claude Code finishes its UI update.
_notify_focus() {
	if _tmux_auto_focus_enabled; then
		# 0.5s delay gives Claude Code time to finish its terminal UI update
		# before we switch panes. The threshold has not been measured.
		(sleep 0.25 && tmux select-pane -t "${TMUX_PANE}") &
		disown
	fi
}

# ---------------------------------------------------------------------------
# Event handler
# ---------------------------------------------------------------------------

# Handle a Stop or Notification event
_handle_event() {
	local event="$1"

	if _tmux_is_active_pane; then
		return 0
	fi

	_notify_bell

	local window
	window="$(_tmux_pane_window_name)"

	case "$event" in
	Stop)
		_notify_message "Claude [${window}]: done"
		;;
	Notification)
		_notify_message "Claude [${window}]: waiting"
		;;
	esac

	_notify_focus
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

# Guards against non-tmux environments, reads the event args from stdin,
# and dispatches to the appropriate event handler.
main() {
	if [[ -z "${TMUX:-}" ]] || [[ -z "${TMUX_PANE:-}" ]]; then
		exit 0
	fi

	local event_args
	event_args="$(cat)"

	local event_name
	event_name="$(_json_field "hook_event_name" "$event_args")"

	case "$event_name" in
	Stop | Notification)
		_handle_event "$event_name"
		;;
	esac
}

main "$@"
