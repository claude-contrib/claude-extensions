#!/usr/bin/env bash
#
# linux.sh - Linux backend for os-notify (sourced by os-notify.sh)
#
# Notifications are sent with notify-send (libnotify). On X11 sessions the
# backend also:
#
#   - detects whether the terminal window is the active window (via xprop),
#     so notifications are suppressed while you are looking at Claude
#   - raises the terminal window and switches the tmux window when the
#     notification is clicked (needs notify-send >= 0.8 and a notification
#     daemon that supports actions)
#
# The terminal window is found, in order, with:
#   1. $WINDOWID, when the terminal sets it
#   2. @claude-notify-terminal, when set: matched against WM_CLASS (case
#      insensitive, instance or class; a trailing component is enough, so
#      "wezterm" matches "org.wezfurlong.wezterm")
#   3. process ancestry: the window whose _NET_WM_PID is an ancestor of this
#      process (under tmux: of the most recently active client attached to
#      Claude's session). This needs no configuration.
#
# Windows are raised with i3-msg (i3), wmctrl or xdotool, whichever is available.
#
# Wayland sessions get plain notifications only: there is no portable way to
# read the focused window or to take focus there.

# Exits 1 with a message if notify-send is not installed.
_os_check_dependencies() {
	if ! command -v notify-send &>/dev/null; then
		echo "os-notify: notify-send not found. Install libnotify (e.g. apt install libnotify-bin, dnf install libnotify, pacman -S libnotify)" >&2
		exit 1
	fi
}

# ---------------------------------------------------------------------------
# X11 window helpers
# ---------------------------------------------------------------------------

# Returns 0 in an X11 session where xprop is available.
_linux_has_x11() {
	[[ -n "${DISPLAY:-}" ]] &&
		[[ "${XDG_SESSION_TYPE:-}" != "wayland" ]] &&
		command -v xprop &>/dev/null
}

# Prints a window id as a decimal number (accepts hex like 0x1800004).
_linux_window_number() {
	printf '%d' "$1" 2>/dev/null || true
}

# Prints the id (hex) of the active window, or nothing if there is none.
_linux_active_window() {
	local id
	id="$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null | sed -n 's/.*# *\(0x[0-9a-fA-F]*\).*/\1/p')"
	[[ "$id" != "0x0" ]] && echo "$id"
	return 0
}

# Prints the WM_CLASS values (instance, class) of a window, one per line.
#
# Args:
#   $1 - Window id
_linux_window_classes() {
	xprop -id "$1" WM_CLASS 2>/dev/null |
		sed -n 's/^WM_CLASS(STRING) = //p' |
		tr -d '" ' | tr ',' '\n'
}

# Returns 0 if any WM_CLASS value of a window equals a name or ends with ".name"
# (case insensitive), so "wezterm" matches "org.wezfurlong.wezterm".
#
# Args:
#   $1 - Window id
#   $2 - Class or instance name
_linux_window_has_class() {
	local want="${2,,}" value
	while IFS= read -r value; do
		[[ "${value,,}" == "$want" || "${value,,}" == *".${want}" ]] && return 0
	done < <(_linux_window_classes "$1")
	return 1
}

# Prints the _NET_WM_PID of a window, or nothing.
#
# Args:
#   $1 - Window id
_linux_window_pid() {
	xprop -id "$1" _NET_WM_PID 2>/dev/null | sed -n 's/^_NET_WM_PID(CARDINAL) = //p'
}

# Prints the ids of all candidate terminal windows, one per line (see the
# resolution order in the file header).
_linux_terminal_windows() {
	if [[ -n "${WINDOWID:-}" ]]; then
		echo "$WINDOWID"
		return 0
	fi

	local id name
	local windows
	windows="$(xprop -root _NET_CLIENT_LIST 2>/dev/null | grep -o '0x[0-9a-fA-F]*' || true)"

	name="$(_tmux_option "@claude-notify-terminal" "")"
	if [[ -n "$name" ]]; then
		for id in $windows; do
			if _linux_window_has_class "$id" "$name"; then
				echo "$id"
			fi
		done
		return 0
	fi

	local ancestors pid
	ancestors="$(_ancestor_pids "$(_terminal_start_pid)")"
	for id in $windows; do
		pid="$(_linux_window_pid "$id")"
		if [[ -n "$pid" ]] && grep -qx -- "$pid" <<<"$ancestors"; then
			echo "$id"
		fi
	done
}

# Prints the id of the terminal window to raise: the active one if it is a
# candidate, otherwise the first candidate. Fails when there is none.
_linux_terminal_window() {
	local candidates active first="" id
	candidates="$(_linux_terminal_windows)"
	active="$(_linux_active_window)"
	for id in $candidates; do
		[[ -n "$first" ]] || first="$id"
		if [[ -n "$active" ]] && [[ "$(_linux_window_number "$id")" == "$(_linux_window_number "$active")" ]]; then
			echo "$id"
			return 0
		fi
	done
	[[ -n "$first" ]] || return 1
	echo "$first"
}

# Returns 0 if the active window is one of the terminal windows.
_os_is_terminal_focused() {
	_linux_has_x11 || return 1

	local active id
	active="$(_linux_active_window)"
	[[ -n "$active" ]] || return 1

	for id in $(_linux_terminal_windows); do
		[[ "$(_linux_window_number "$id")" == "$(_linux_window_number "$active")" ]] && return 0
	done
	return 1
}

# Raises a window using the first available tool.
#
# Args:
#   $1 - Window id
#
# Returns 1 when no tool could do it.
_linux_activate_window() {
	local id number
	id="$1"
	number="$(_linux_window_number "$id")"
	[[ -n "$number" ]] || return 1

	if command -v i3-msg &>/dev/null && i3-msg -t get_version &>/dev/null; then
		i3-msg "[id=${number}] focus" &>/dev/null
	elif command -v wmctrl &>/dev/null; then
		wmctrl -i -a "$id"
	elif command -v xdotool &>/dev/null; then
		xdotool windowactivate "$number"
	else
		return 1
	fi
}

# Raise the terminal window and switch to Claude's tmux window.
#
# Args:
#   $1 - tmux session name (empty when not in tmux)
#   $2 - tmux window id (e.g. @4)
#   $3 - tmux client tty (e.g. /dev/pts/3)
_linux_focus() {
	local tmux_session="$1" tmux_window="$2" tmux_client="$3"

	if _linux_has_x11; then
		local window
		window="$(_linux_terminal_window || true)"
		[[ -z "$window" ]] || _linux_activate_window "$window" || true
	fi

	if [[ -n "$tmux_client" ]] && [[ -n "$tmux_session" ]] && [[ -n "$tmux_window" ]]; then
		tmux switch-client -c "$tmux_client" -t "${tmux_session}:${tmux_window}"
	fi
}

# Returns 0 if notify-send supports --action (libnotify 0.8 and later).
_linux_notify_send_has_actions() {
	notify-send --help 2>&1 | grep -q -- '--action'
}

# ---------------------------------------------------------------------------
# Sending
# ---------------------------------------------------------------------------

# Ask with one button per label and wait for the answer.
#
# Args:
#   $1 - Title
#   $2 - Body
#   $3 - Sound name, or empty to omit sound (see _os_send)
#   $4 - Seconds to wait for a click
#   $5... - Button labels
#
# Prints the label of the clicked button. Prints nothing when the notification is dismissed
# or times out, or when notify-send has no --action support or there is no
# `timeout` command to bound the wait.
_os_ask() {
	local title="$1" body="$2" sound="$3" wait="$4"
	shift 4
	_linux_notify_send_has_actions || return 0
	command -v timeout &>/dev/null || return 0

	# Actions are named by index, so a label never has to be a valid action name.
	local labels=("$@") args=(-a "Claude Code" -i dialog-information -h "string:x-canonical-private-synchronous:claude-code-ask") i
	for i in "${!labels[@]}"; do
		args+=(-A "${i}=${labels[$i]}")
	done
	if [[ -n "$sound" ]]; then
		args+=(-h "string:sound-name:message-new-instant")
	fi

	local chosen
	chosen="$(timeout "$wait" notify-send "${args[@]}" -- "$title" "$body" 2>/dev/null || true)"
	[[ "$chosen" =~ ^[0-9]+$ ]] || return 0
	if ((chosen < ${#labels[@]})); then
		echo "${labels[$chosen]}"
	fi
}

# Show a notification.
#
# When actions are supported, notify-send waits for a click, so it runs in a
# detached background process: the hook returns immediately, and clicking the
# notification focuses the terminal.
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

	if ! _linux_notify_send_has_actions; then
		notify-send "${args[@]}" -- "$title" "$body"
		return
	fi

	local tmux_session="" tmux_window="" tmux_client=""
	if [[ -n "${TMUX:-}" ]] && [[ -n "${TMUX_PANE:-}" ]]; then
		tmux_session="$(_tmux_session_name)"
		tmux_window="$(_tmux_window_id)"
		tmux_client="$(_tmux_client_tty)"
	fi

	# "default" is the action the daemon runs when the notification body is clicked.
	args+=(-A "default=Focus terminal")

	# All file descriptors are redirected so the hook does not wait for this process.
	(
		local chosen
		chosen="$(notify-send "${args[@]}" -- "$title" "$body" 2>/dev/null || true)"
		if [[ "$chosen" == "default" ]]; then
			_linux_focus "$tmux_session" "$tmux_window" "$tmux_client"
		fi
	) >/dev/null 2>&1 </dev/null &
	disown
}
