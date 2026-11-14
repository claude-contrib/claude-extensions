#!/usr/bin/env bash
#
# os-notify.sh - native desktop notification hook for Claude Code
#
# DESCRIPTION:
#   Sends native desktop notifications when Claude Code needs attention.
#   OS-specific behaviour lives in scripts/backends/<os>.sh, which must define:
#
#     _os_check_dependencies           exit non-zero (with a message) if unusable
#     _os_is_terminal_focused          0 if the terminal app is frontmost
#     _os_send TITLE SUBTITLE SOUND    show the notification
#     _os_ask TITLE BODY SOUND SECS LABEL...
#                                      ask with one button per LABEL, wait up to SECS,
#                                      print the clicked label (nothing otherwise)
#
#   Supported backends:
#     macos  terminal-notifier (click-to-focus), falls back to osascript
#     linux  notify-send (libnotify); on X11 also focus detection and click-to-focus
#
# USAGE:
#   Invoked automatically by Claude Code hooks on Notification events
#   (permission_prompt, elicitation_dialog) and on PreToolUse for AskUserQuestion.
#
# TMUX OPTIONS (set via tmux set-option -g <option> <value>):
#   @claude-notify-terminal  (unset)  - optional override for the terminal used in focus detection and
#                                       click-to-focus. By default it is detected from the process
#                                       tree. macOS: application name ("Ghostty", "iTerm2");
#                                       X11: WM_CLASS ("ghostty", "wezterm", "kitty").
#   @claude-notify-sound     on        - Play a sound with the notification
#
# STDIN (JSON from Claude Code):
#   hook_event_name  - "Notification" or "PreToolUse"
#   tool_name        - "AskUserQuestion" (PreToolUse only; other tools are ignored)
#
# EXIT CODES:
#   0 - Success (including graceful no-op on unsupported OS)
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
		[[ -z "${DEBUG:-}" ]] || echo "[os-notify] WARNING: jq not found, using sed fallback for JSON parsing" >&2
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

# Prints the PID of the most recently active tmux client attached to Claude's
# session (or of any client when that session has none), or nothing.
_tmux_client_pid() {
	local session clients format='#{client_activity} #{client_pid}'
	session="$(_tmux_session_name)"
	clients=""
	if [[ -n "$session" ]]; then
		clients="$(tmux list-clients -t "$session" -F "$format" 2>/dev/null || true)"
	fi
	if [[ -z "$clients" ]]; then
		clients="$(tmux list-clients -F "$format" 2>/dev/null || true)"
	fi
	printf '%s\n' "$clients" | sort -rn | awk 'NR==1 { print $2 }'
}

# Prints a PID followed by all its ancestors (excluding PID 1), one per line.
#
# Args:
#   $1 - PID
_ancestor_pids() {
	local pid="$1" parent
	while [[ -n "$pid" ]] && [[ "$pid" -gt 1 ]] 2>/dev/null; do
		echo "$pid"
		parent="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
		[[ "$parent" != "$pid" ]] || break
		pid="$parent"
	done
}

# Prints the PID whose ancestors lead to the terminal: the tmux client under
# tmux (the tmux server is detached from the terminal), otherwise this process.
_terminal_start_pid() {
	if [[ -n "${TMUX:-}" ]]; then
		_tmux_client_pid
	else
		echo "$$"
	fi
}

# ---------------------------------------------------------------------------
# Config predicates
# ---------------------------------------------------------------------------

# Returns 0 if @claude-notify-sound is enabled
_tmux_sound_enabled() {
	[[ "$(_tmux_option "@claude-notify-sound" "on")" == "on" ]]
}

# Returns 0 if @claude-notify-buttons is enabled (Allow/Deny buttons on
# permission notifications)
_tmux_buttons_enabled() {
	[[ "$(_tmux_option "@claude-notify-buttons" "on")" == "on" ]]
}

# Prints how many seconds a permission notification waits for a click. Keep it
# below the hook timeout in hooks.json, or Claude Code kills the hook first.
_ask_timeout() {
	local value
	value="$(_tmux_option "@claude-notify-ask-timeout" "25")"
	[[ "$value" =~ ^[0-9]+$ ]] || value=25
	echo "$value"
}

# ---------------------------------------------------------------------------
# State predicates
# ---------------------------------------------------------------------------

# Returns 0 if the active tmux session and window match Claude's pane.
_tmux_is_active_window() {
	[[ "$(_tmux_active_session_id)" == "$(_tmux_pane_session_id)" ]] &&
		[[ "$(_tmux_active_window_id)" == "$(_tmux_window_id)" ]]
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
# Backend loading
# ---------------------------------------------------------------------------

# Prints the backend name for the current OS (macos, linux), or nothing when
# the OS is unsupported.
_backend_name() {
	case "$(uname -s)" in
	Darwin) echo "macos" ;;
	Linux) echo "linux" ;;
	esac
}

# Sources the backend for the current OS.
#
# Returns 1 when the OS is unsupported.
_load_backend() {
	local backend
	backend="$(_backend_name)"
	[[ -n "$backend" ]] || return 1
	# shellcheck source=/dev/null
	source "$(_scripts_dir)/backends/${backend}.sh"
}

# ---------------------------------------------------------------------------
# Notification actions
# ---------------------------------------------------------------------------

# Send a notification through the active backend.
#
# Args:
#   $1 - Title (project name)
#   $2 - Subtitle text (current git branch will be appended automatically)
#   $3 - Sound name (e.g. "Ping"), or empty to omit sound
_notify_alert() {
	local title="$1"
	local subtitle="$2"
	local sound="$3"

	local git_branch
	git_branch="$(_git_branch)"

	if [[ -n "$git_branch" ]]; then
		subtitle="${subtitle} — ${git_branch}"
	fi

	_os_send "$title" "$subtitle" "$sound"
}

# ---------------------------------------------------------------------------
# Event handler
# ---------------------------------------------------------------------------

# Returns 0 if the user is looking at Claude's terminal (and, under tmux, at
# Claude's window), so no notification is needed.
_user_is_present() {
	_os_is_terminal_focused || return 1
	[[ -z "${TMUX:-}" ]] || _tmux_is_active_window
}

# Prints a one-line description of a permission request for the notification.
#
# Starts with "Allow <tool>?" so the text never begins with a character that
# the notifier would read as an option. The tool's command, file path or URL
# follows when jq is available, cut to 120 characters on one line.
#
# Args:
#   $1 - JSON event_args
_permission_summary() {
	local json="$1" tool detail=""
	tool="$(_json_field "tool_name" "$json")"
	if command -v jq &>/dev/null; then
		detail="$(printf '%s' "$json" |
			jq -r '.tool_input | (.command // .file_path // .path // .url // empty) | tostring' 2>/dev/null |
			tr '\n' ' ' | cut -c1-120 | sed 's/[[:space:]]*$//' || true)"
	fi
	if [[ -n "$detail" ]]; then
		echo "Allow ${tool}? ${detail}"
	else
		echo "Allow ${tool}?"
	fi
}

# Prints the button labels for an AskUserQuestion request, one per line, and
# returns 0, when the question fits notification buttons. Returns 1 otherwise.
#
# It fits when jq is available, there is exactly one question, it is not
# multi-select, and it has 2 to 4 options whose labels are 1 to 40 characters on
# one line and start with a letter or digit, so the notifier never reads a label
# as an option.
#
# Args:
#   $1 - JSON event_args
_question_choices() {
	local json="$1" labels label count=0
	command -v jq &>/dev/null || return 1
	labels="$(printf '%s' "$json" | jq -r '
		.tool_input.questions
		| select(type == "array" and length == 1 and (.[0].multiSelect // false) == false)
		| .[0].options
		| select(type == "array" and length >= 2 and length <= 4
			and all(.[]; (.label | type == "string") and ((.label | contains("\n")) | not)))
		| .[].label' 2>/dev/null)" || return 1
	[[ -n "$labels" ]] || return 1
	while IFS= read -r label; do
		[[ ${#label} -ge 1 && ${#label} -le 40 && "$label" =~ ^[[:alnum:]] ]] || return 1
		count=$((count + 1))
	done <<<"$labels"
	((count >= 2 && count <= 4)) || return 1
	printf '%s\n' "$labels"
}

# Prints the question text of an AskUserQuestion request on one line, cut to
# 160 characters.
#
# Args:
#   $1 - JSON event_args
_question_text() {
	printf '%s' "$1" |
		jq -r '.tool_input.questions[0].question // empty' 2>/dev/null |
		tr '\n' ' ' | cut -c1-160 | sed 's/[[:space:]]*$//' || true
}

# Handle an AskUserQuestion request: when the user is away and the question fits
# buttons (see _question_choices), ask with one button per option and print the
# decision JSON that answers it.
#
# Prints nothing, which leaves the question in the terminal, when the user is
# present, buttons are off, the question does not fit, or the notification is
# dismissed or times out.
#
# Args:
#   $1 - JSON event_args
_handle_question_request() {
	local event_args="$1" labels label
	_tmux_buttons_enabled || return 0
	labels="$(_question_choices "$event_args")" || return 0
	if _user_is_present; then
		return 0
	fi

	local sound="Ping"
	if ! _tmux_sound_enabled; then
		sound=""
	fi

	local choices=()
	while IFS= read -r label; do
		choices+=("$label")
	done <<<"$labels"

	local choice
	choice="$(_os_ask "$(_project_name)" "Claude asks: $(_question_text "$event_args")" "$sound" "$(_ask_timeout)" "${choices[@]}")"
	[[ -n "$choice" ]] || return 0

	printf '%s' "$event_args" | jq -c --arg a "$choice" '
		.tool_input.questions[0].question as $q
		| {hookSpecificOutput: {hookEventName: "PermissionRequest", decision: {
			behavior: "allow",
			updatedInput: (.tool_input + {answers: {($q): $a}})}}}'
}

# Handle a PermissionRequest event: when the user is away, ask with Allow and
# Deny buttons and print the decision JSON for Claude Code.
#
# Prints nothing, which leaves the normal permission dialog in place, when the
# user is present, buttons are off, or the notification is dismissed, times
# out, or the notifier has no buttons. AskUserQuestion goes to
# _handle_question_request, and ExitPlanMode is skipped: it needs a plan review,
# not a yes or no.
#
# Args:
#   $1 - JSON event_args
_handle_permission_request() {
	local event_args="$1" tool
	tool="$(_json_field "tool_name" "$event_args")"
	case "$tool" in
	"" | ExitPlanMode) return 0 ;;
	AskUserQuestion)
		_handle_question_request "$event_args"
		return
		;;
	esac

	_tmux_buttons_enabled || return 0
	if _user_is_present; then
		return 0
	fi

	local sound="Ping"
	if ! _tmux_sound_enabled; then
		sound=""
	fi

	local choice
	choice="$(_os_ask "$(_project_name)" "$(_permission_summary "$event_args")" "$sound" "$(_ask_timeout)" Allow Deny)"

	case "$choice" in
	Allow)
		printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
		;;
	Deny)
		printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","message":"Denied from the desktop notification"}}}'
		;;
	esac
}

# Handle an event that needs the user's attention
#
# Args:
#   $1 - Notification text (default: "Claude needs your input")
_handle_event() {
	if _user_is_present; then
		return 0
	fi

	local alert_title
	alert_title="$(_project_name)"

	local alert_subtitle="${1:-Claude needs your input}"

	local alert_sound="Ping"
	if ! _tmux_sound_enabled; then
		alert_sound=""
	fi

	_notify_alert "$alert_title" "$alert_subtitle" "$alert_sound"
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

# Loads the backend and checks its dependencies.
#
# Exits 0 silently on unsupported operating systems (graceful no-op).
_check_dependencies() {
	_load_backend || exit 0
	_os_check_dependencies
}

# Loads the backend, reads the event args from stdin, and dispatches to the
# event handler.
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
	PermissionRequest)
		_handle_permission_request "$event_args"
		;;
	PreToolUse)
		# The AskUserQuestion form sends no Notification event, so it is
		# caught here. When the question fits buttons, the PermissionRequest
		# hook asks with buttons instead, so this alert would be a duplicate.
		if [[ "$(_json_field "tool_name" "$event_args")" == "AskUserQuestion" ]]; then
			if ! _tmux_buttons_enabled || ! _question_choices "$event_args" >/dev/null; then
				_handle_event "Claude has a question"
			fi
		fi
		;;
	esac
}

[[ "${BASH_SOURCE[0]}" != "${0}" ]] || main "$@"
