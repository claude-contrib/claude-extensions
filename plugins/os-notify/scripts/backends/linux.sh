#!/usr/bin/env bash
#
# linux.sh - Linux backend for os-notify (sourced by os-notify.sh)
#
# Uses notify-send (libnotify). Focus detection and click-to-focus are not
# implemented yet, so notifications are never suppressed and clicking them
# does nothing.

# Exits 1 with a message if notify-send is not installed.
_os_check_dependencies() {
	if ! command -v notify-send &>/dev/null; then
		echo "os-notify: notify-send not found. Install libnotify (e.g. apt install libnotify-bin, dnf install libnotify, pacman -S libnotify)" >&2
		exit 1
	fi
}

# Focus detection is not implemented on Linux; always report "not focused" so
# the notification is shown.
_os_is_terminal_focused() {
	return 1
}

# Show a notification.
#
# Args:
#   $1 - Title
#   $2 - Body (subtitle)
#   $3 - Sound name, or empty to omit sound. Sent as the freedesktop
#        `sound-name` hint, which only some notification daemons honor, so any
#        non-empty value is mapped to the standard "message-new-instant" sound.
_os_send() {
	local title="$1" body="$2" sound="$3"

	local args=(-a "Claude Code" -i dialog-information -h "string:x-canonical-private-synchronous:claude-code")
	if [[ -n "$sound" ]]; then
		args+=(-h "string:sound-name:message-new-instant")
	fi

	notify-send "${args[@]}" -- "$title" "$body"
}
