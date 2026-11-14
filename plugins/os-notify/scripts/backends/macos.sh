#!/usr/bin/env bash
#
# macos.sh - macOS backend for os-notify (sourced by os-notify.sh)
#
# Uses terminal-notifier when available (supports click-to-focus via
# macos-focus.sh), otherwise falls back to osascript's `display notification`
# (no click action).

# Fails if no notification mechanism is available. osascript ships with macOS,
# so this only warns when terminal-notifier is missing.
_os_check_dependencies() {
	if ! command -v terminal-notifier &>/dev/null; then
		[[ -z "${DEBUG:-}" ]] || echo "[os-notify] terminal-notifier not found, falling back to osascript (no click-to-focus). Install with: brew install terminal-notifier" >&2
	fi
}

# Returns 0 if the configured terminal app is the frontmost macOS application.
_os_is_terminal_focused() {
	local app_name
	app_name="$(_tmux_option "@claude-notify-terminal" "Ghostty")"

	local frontmost
	frontmost="$(osascript "$(_scripts_dir)/backends/macos-active.scpt" 2>/dev/null || true)"

	[[ "$frontmost" == "$app_name" ]]
}

# Build the shell-quoted focus command string passed to terminal-notifier -execute.
#
# Reads tmux state directly from the environment. When not running inside tmux,
# session/window/client args are passed as empty strings so macos-focus.sh
# skips the tmux window switch and only activates the terminal app.
_macos_focus_command() {
	local tmux_session="" tmux_window="" tmux_client=""
	if [[ -n "${TMUX:-}" ]] && [[ -n "${TMUX_PANE:-}" ]]; then
		tmux_session="$(_tmux_session_name)"
		tmux_window="$(_tmux_window_id)"
		tmux_client="$(_tmux_client_tty)"
	fi

	local tmux_bin cmd
	tmux_bin="$(command -v tmux 2>/dev/null || true)"

	printf -v cmd '%q ' "$(_scripts_dir)/backends/macos-focus.sh" "$tmux_bin" "$tmux_session" "$tmux_window" "$tmux_client"
	echo "${cmd% }"
}

# Show a notification.
#
# Args:
#   $1 - Title
#   $2 - Message body. terminal-notifier 3.x rejects a blank -message, so the
#        text goes in the message rather than in -subtitle.
#   $3 - Sound name (e.g. "Ping"), or empty to omit sound
_os_send() {
	local title="$1" subtitle="$2" sound="$3"

	if command -v terminal-notifier &>/dev/null; then
		local notify_args=(-title "$title" -message "$subtitle" -group "claude-code" -execute "$(_macos_focus_command)")
		if [[ -n "$sound" ]]; then
			notify_args+=(-sound "$sound")
		fi
		terminal-notifier "${notify_args[@]}"
		return
	fi

	# Fallback: values are passed as argv, so no quoting/escaping issues.
	osascript \
		-e 'on run argv' \
		-e 'set t to item 1 of argv' \
		-e 'set s to item 2 of argv' \
		-e 'set snd to item 3 of argv' \
		-e 'if snd is "" then' \
		-e 'display notification s with title t' \
		-e 'else' \
		-e 'display notification s with title t sound name snd' \
		-e 'end if' \
		-e 'end run' \
		-- "$title" "$subtitle" "$sound"
}
