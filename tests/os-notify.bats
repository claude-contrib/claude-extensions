#!/usr/bin/env bats
#
# tests/os-notify.bats — BATS tests for plugins/os-notify/scripts/os-notify.sh
#
# Run:
#   bats tests/os-notify.bats

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/plugins/os-notify/scripts/os-notify.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Source the script without running main, with the backend for $1 loaded
# (default: macos). Stubs uname so the backend is selected regardless of the
# host OS, and stubs the notifier commands so nothing is actually sent.
_load() {
	local os="${1:-Darwin}"
	terminal-notifier() { :; }
	notify-send() { :; }
	export -f terminal-notifier notify-send
	eval "uname() { echo $os; }"
	export -f uname
	TMUX="" TMUX_PANE="" source "$SCRIPT"
	_load_backend
}

# ---------------------------------------------------------------------------
# _json_field
# ---------------------------------------------------------------------------

@test "_json_field: extracts a string field with jq" {
	_load
	result="$(_json_field "hook_event_name" '{"hook_event_name":"Notification"}')"
	[ "$result" = "Notification" ]
}

@test "_json_field: returns empty string for missing field" {
	_load
	result="$(_json_field "missing" '{"hook_event_name":"Notification"}')"
	[ -z "$result" ]
}

@test "_json_field: returns empty string for empty JSON object" {
	_load
	result="$(_json_field "hook_event_name" '{}')"
	[ -z "$result" ]
}

# ---------------------------------------------------------------------------
# _project_name
# ---------------------------------------------------------------------------

@test "_project_name: returns basename of PWD when not in a git repo" {
	_load
	# Override git to simulate no repo
	git() { return 1; }
	export -f git
	_orig_pwd="$PWD"
	cd /tmp
	result="$(_project_name)"
	cd "$_orig_pwd"
	[ "$result" = "tmp" ]
}

@test "_project_name: returns owner/repo from git remote when available" {
	_load
	git() {
		case "$*" in
			"rev-parse --show-toplevel") echo "/fake/repo" ;;
			"remote get-url origin") echo "git@github.com:owner/repo.git" ;;
		esac
	}
	export -f git
	result="$(_project_name)"
	[ "$result" = "owner/repo" ]
}

@test "_project_name: falls back to git root basename when no remote" {
	_load
	git() {
		case "$*" in
			"rev-parse --show-toplevel") echo "/fake/my-project" ;;
			*) return 1 ;;
		esac
	}
	export -f git
	result="$(_project_name)"
	[ "$result" = "my-project" ]
}

# ---------------------------------------------------------------------------
# _git_branch
# ---------------------------------------------------------------------------

@test "_git_branch: returns empty string when not in git repo" {
	_load
	git() { return 1; }
	export -f git
	result="$(_git_branch)"
	[ -z "$result" ]
}

@test "_git_branch: returns branch name" {
	_load
	git() { echo "main"; }
	export -f git
	result="$(_git_branch)"
	[ "$result" = "main" ]
}

# ---------------------------------------------------------------------------
# Config predicates
# ---------------------------------------------------------------------------

@test "_tmux_sound_enabled: returns true when option is 'on'" {
	_load
	_tmux_option() { echo "on"; }
	_tmux_sound_enabled
}

@test "_tmux_sound_enabled: returns false when option is 'off'" {
	_load
	_tmux_option() { echo "off"; }
	run _tmux_sound_enabled
	[ "$status" -ne 0 ]
}

@test "_tmux_sound_enabled: default is 'on'" {
	_load
	tmux() { return 1; }
	export -f tmux
	_tmux_sound_enabled
}

# ---------------------------------------------------------------------------
# State predicates
# ---------------------------------------------------------------------------

@test "_tmux_is_active_window: true when session and window IDs match" {
	_load
	_tmux_active_session_id() { echo "\$1"; }
	_tmux_pane_session_id() { echo "\$1"; }
	_tmux_active_window_id() { echo "@4"; }
	_tmux_window_id() { echo "@4"; }
	_tmux_is_active_window
}

@test "_tmux_is_active_window: false when window IDs differ" {
	_load
	_tmux_active_session_id() { echo "\$1"; }
	_tmux_pane_session_id() { echo "\$1"; }
	_tmux_active_window_id() { echo "@4"; }
	_tmux_window_id() { echo "@5"; }
	run _tmux_is_active_window
	[ "$status" -ne 0 ]
}

@test "_tmux_is_active_window: false when session IDs differ" {
	_load
	_tmux_active_session_id() { echo "\$1"; }
	_tmux_pane_session_id() { echo "\$2"; }
	_tmux_active_window_id() { echo "@4"; }
	_tmux_window_id() { echo "@4"; }
	run _tmux_is_active_window
	[ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Backend selection
# ---------------------------------------------------------------------------

@test "_backend_name: Darwin maps to macos" {
	_load Darwin
	[ "$(_backend_name)" = "macos" ]
}

@test "_backend_name: Linux maps to linux" {
	_load Linux
	[ "$(_backend_name)" = "linux" ]
}

@test "_backend_name: unsupported OS yields nothing" {
	_load Darwin
	uname() { echo "FreeBSD"; }
	[ -z "$(_backend_name)" ]
}

@test "_load_backend: fails on unsupported OS" {
	_load Darwin
	uname() { echo "FreeBSD"; }
	run _load_backend
	[ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# _check_dependencies
# ---------------------------------------------------------------------------

@test "_check_dependencies: exits 0 on unsupported OS" {
	_load Darwin
	uname() { echo "FreeBSD"; }
	run _check_dependencies
	[ "$status" -eq 0 ]
}

@test "_check_dependencies: macOS succeeds without terminal-notifier (osascript fallback)" {
	_load Darwin
	command() { return 1; }
	run _check_dependencies
	[ "$status" -eq 0 ]
}

@test "_check_dependencies: Linux exits 1 when notify-send not found" {
	_load Linux
	command() { return 1; }
	run _check_dependencies
	[ "$status" -eq 1 ]
}

@test "_check_dependencies: Linux succeeds when notify-send is present" {
	_load Linux
	run _check_dependencies
	[ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# macOS backend: _os_send
# ---------------------------------------------------------------------------

@test "macos _os_send: uses terminal-notifier with title, message, sound and focus command" {
	_load Darwin
	_macos_focus_command() { echo "FOCUS"; }
	terminal-notifier() { printf '%s\n' "$@" >"$BATS_TEST_TMPDIR/args"; }
	_os_send "owner/repo" "needs input" "Ping"
	grep -qx "owner/repo" "$BATS_TEST_TMPDIR/args"
	grep -qx "needs input" "$BATS_TEST_TMPDIR/args"
	grep -qx "FOCUS" "$BATS_TEST_TMPDIR/args"
	grep -qx "Ping" "$BATS_TEST_TMPDIR/args"
}

@test "macos _os_send: omits -sound when sound is empty" {
	_load Darwin
	_macos_focus_command() { echo "FOCUS"; }
	terminal-notifier() { printf '%s\n' "$@" >"$BATS_TEST_TMPDIR/args"; }
	_os_send "t" "s" ""
	! grep -qx -- "-sound" "$BATS_TEST_TMPDIR/args"
}

@test "macos _os_send: falls back to osascript when terminal-notifier is missing" {
	_load Darwin
	command() { [[ "$2" != "terminal-notifier" ]]; }
	osascript() { printf '%s\n' "$@" >"$BATS_TEST_TMPDIR/args"; }
	_os_send 'ti"tle' "sub" "Ping"
	grep -qx 'ti"tle' "$BATS_TEST_TMPDIR/args"
	grep -qx "Ping" "$BATS_TEST_TMPDIR/args"
}

# ---------------------------------------------------------------------------
# Linux backend: _os_send
# ---------------------------------------------------------------------------

# notify-send stub that records its arguments and, like libnotify 0.8, lists
# --action in --help. $NOTIFY_HAS_ACTIONS=0 simulates an older libnotify.
_stub_notify_send() {
	notify-send() {
		if [[ "${1:-}" == "--help" ]]; then
			[[ "${NOTIFY_HAS_ACTIONS:-1}" == "1" ]] && echo "  -A, --action=[NAME=]Text..."
			return 0
		fi
		printf '%s\n' "$@" >"$BATS_TEST_TMPDIR/args"
		echo "${NOTIFY_CHOSEN:-}"
	}
	export -f notify-send
}

@test "linux _os_send: without action support, calls notify-send in the foreground with title and body after --" {
	_load Linux
	NOTIFY_HAS_ACTIONS=0 _stub_notify_send
	NOTIFY_HAS_ACTIONS=0 _os_send "owner/repo" "needs input" "Ping"
	[ "$(tail -n 2 "$BATS_TEST_TMPDIR/args")" = "$(printf 'owner/repo\nneeds input')" ]
	grep -qx -- "--" "$BATS_TEST_TMPDIR/args"
	grep -qx "string:sound-name:message-new-instant" "$BATS_TEST_TMPDIR/args"
	! grep -q -- "--action\|^-A$" "$BATS_TEST_TMPDIR/args"
}

@test "linux _os_send: omits sound hint when sound is empty" {
	_load Linux
	NOTIFY_HAS_ACTIONS=0 _stub_notify_send
	NOTIFY_HAS_ACTIONS=0 _os_send "t" "b" ""
	! grep -q "sound-name" "$BATS_TEST_TMPDIR/args"
}

@test "linux _os_send: title starting with a dash is not parsed as an option" {
	_load Linux
	NOTIFY_HAS_ACTIONS=0 _stub_notify_send
	NOTIFY_HAS_ACTIONS=0 _os_send "-evil" "b" ""
	[ "$(grep -nx -- '--' "$BATS_TEST_TMPDIR/args" | cut -d: -f1)" -lt "$(grep -nx -- '-evil' "$BATS_TEST_TMPDIR/args" | cut -d: -f1)" ]
}

@test "linux _os_send: with action support, adds the default action and returns without waiting" {
	_load Linux
	_stub_notify_send
	_linux_focus() { echo "FOCUSED" >"$BATS_TEST_TMPDIR/focus"; }
	NOTIFY_CHOSEN="" _os_send "t" "b" ""
	wait_for_file() { for _ in $(seq 50); do [[ -e "$1" ]] && return 0; sleep 0.1; done; return 1; }
	wait_for_file "$BATS_TEST_TMPDIR/args"
	grep -qx "default=Focus terminal" "$BATS_TEST_TMPDIR/args"
	[ ! -e "$BATS_TEST_TMPDIR/focus" ]
}

@test "linux _os_send: focuses the terminal when the default action is chosen" {
	_load Linux
	_stub_notify_send
	_linux_focus() { printf '%s|%s|%s' "$1" "$2" "$3" >"$BATS_TEST_TMPDIR/focus"; }
	_tmux_session_name() { echo "work"; }
	_tmux_window_id() { echo "@4"; }
	_tmux_client_tty() { echo "/dev/pts/3"; }
	TMUX="x" TMUX_PANE="%1" NOTIFY_CHOSEN="default" _os_send "t" "b" ""
	for _ in $(seq 50); do [[ -e "$BATS_TEST_TMPDIR/focus" ]] && break; sleep 0.1; done
	[ "$(cat "$BATS_TEST_TMPDIR/focus")" = "work|@4|/dev/pts/3" ]
}

# ---------------------------------------------------------------------------
# Linux backend: X11 focus detection
# ---------------------------------------------------------------------------

@test "linux _linux_has_x11: false without DISPLAY" {
	_load Linux
	DISPLAY="" run _linux_has_x11
	[ "$status" -ne 0 ]
}

@test "linux _linux_has_x11: false on a Wayland session" {
	_load Linux
	xprop() { :; }
	export -f xprop
	DISPLAY=":0" XDG_SESSION_TYPE="wayland" run _linux_has_x11
	[ "$status" -ne 0 ]
}

@test "linux _linux_has_x11: true on X11 with xprop" {
	_load Linux
	xprop() { :; }
	export -f xprop
	DISPLAY=":0" XDG_SESSION_TYPE="x11" _linux_has_x11
}

@test "linux _linux_active_window: parses xprop output" {
	_load Linux
	xprop() { echo "_NET_ACTIVE_WINDOW(WINDOW): window id # 0x1800004"; }
	[ "$(_linux_active_window)" = "0x1800004" ]
}

@test "linux _linux_active_window: empty when no window is active" {
	_load Linux
	xprop() { echo "_NET_ACTIVE_WINDOW(WINDOW): window id # 0x0"; }
	[ -z "$(_linux_active_window)" ]
}

@test "linux _linux_window_has_class: matches instance or class, case insensitively" {
	_load Linux
	xprop() { echo 'WM_CLASS(STRING) = "ghostty", "com.mitchellh.Ghostty"'; }
	_linux_window_has_class 0x1 "Ghostty"
	_linux_window_has_class 0x1 "com.mitchellh.ghostty"
	run _linux_window_has_class 0x1 "kitty"
	[ "$status" -ne 0 ]
}

@test "linux _os_is_terminal_focused: false when not on X11" {
	_load Linux
	_linux_has_x11() { return 1; }
	run _os_is_terminal_focused
	[ "$status" -ne 0 ]
}

@test "linux _os_is_terminal_focused: true when active window class matches the option" {
	_load Linux
	_linux_has_x11() { return 0; }
	_linux_active_window() { echo "0x20"; }
	_tmux_option() { echo "wezterm"; }
	xprop() { echo 'WM_CLASS(STRING) = "org.wezfurlong.wezterm", "org.wezfurlong.wezterm"'; }
	WINDOWID="" run _os_is_terminal_focused
	[ "$status" -ne 0 ]
	xprop() { echo 'WM_CLASS(STRING) = "wezterm", "org.wezfurlong.wezterm"'; }
	WINDOWID="" _os_is_terminal_focused
}

@test "linux _os_is_terminal_focused: compares against WINDOWID when set (hex vs decimal)" {
	_load Linux
	_linux_has_x11() { return 0; }
	_linux_active_window() { echo "0x20"; }
	WINDOWID=32 _os_is_terminal_focused
	WINDOWID=33 run _os_is_terminal_focused
	[ "$status" -ne 0 ]
}

@test "linux _os_is_terminal_focused: false when no window is active" {
	_load Linux
	_linux_has_x11() { return 0; }
	_linux_active_window() { :; }
	run _os_is_terminal_focused
	[ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Linux backend: focusing
# ---------------------------------------------------------------------------

@test "linux _linux_terminal_window: prefers WINDOWID" {
	_load Linux
	[ "$(WINDOWID=77 _linux_terminal_window)" = "77" ]
}

@test "linux _linux_terminal_window: finds the first client window matching the class option" {
	_load Linux
	_tmux_option() { echo "kitty"; }
	xprop() {
		case "$*" in
		*_NET_CLIENT_LIST*) echo "_NET_CLIENT_LIST(WINDOW): window id # 0x1, 0x2, 0x3" ;;
		"-id 0x1 WM_CLASS") echo 'WM_CLASS(STRING) = "brave", "Brave"' ;;
		"-id 0x2 WM_CLASS") echo 'WM_CLASS(STRING) = "kitty", "kitty"' ;;
		"-id 0x3 WM_CLASS") echo 'WM_CLASS(STRING) = "kitty", "kitty"' ;;
		esac
	}
	[ "$(WINDOWID="" _linux_terminal_window)" = "0x2" ]
}

@test "linux _linux_terminal_window: fails when nothing matches" {
	_load Linux
	_tmux_option() { echo "kitty"; }
	xprop() { echo "_NET_CLIENT_LIST(WINDOW): window id # 0x1"; }
	WINDOWID="" run _linux_terminal_window
	[ "$status" -ne 0 ]
}

@test "linux _linux_activate_window: uses i3-msg with the decimal id under i3" {
	_load Linux
	i3-msg() { echo "$*" >>"$BATS_TEST_TMPDIR/calls"; }
	export -f i3-msg
	_linux_activate_window 0x20
	grep -q '^\[id=32\] focus$' "$BATS_TEST_TMPDIR/calls"
}

@test "linux _linux_activate_window: falls back to wmctrl when i3 is not running" {
	_load Linux
	i3-msg() { return 1; }
	wmctrl() { echo "$*" >"$BATS_TEST_TMPDIR/calls"; }
	export -f i3-msg wmctrl
	_linux_activate_window 0x20
	[ "$(cat "$BATS_TEST_TMPDIR/calls")" = "-i -a 0x20" ]
}

@test "linux _linux_activate_window: falls back to xdotool" {
	_load Linux
	command() { [[ "$2" == "xdotool" ]]; }
	xdotool() { echo "$*" >"$BATS_TEST_TMPDIR/calls"; }
	_linux_activate_window 0x20
	[ "$(cat "$BATS_TEST_TMPDIR/calls")" = "windowactivate 32" ]
}

@test "linux _linux_activate_window: fails when no tool is available" {
	_load Linux
	command() { return 1; }
	run _linux_activate_window 0x20
	[ "$status" -ne 0 ]
}

@test "linux _linux_focus: activates the window then switches the tmux client" {
	_load Linux
	_linux_has_x11() { return 0; }
	_linux_terminal_window() { echo "0x20"; }
	_linux_activate_window() { echo "activate $1" >>"$BATS_TEST_TMPDIR/calls"; }
	tmux() { echo "tmux $*" >>"$BATS_TEST_TMPDIR/calls"; }
	_linux_focus "work" "@4" "/dev/pts/3"
	[ "$(cat "$BATS_TEST_TMPDIR/calls")" = "$(printf 'activate 0x20\ntmux switch-client -c /dev/pts/3 -t work:@4')" ]
}

@test "linux _linux_focus: skips tmux switch when not in tmux" {
	_load Linux
	_linux_has_x11() { return 1; }
	tmux() { echo "tmux $*" >>"$BATS_TEST_TMPDIR/calls"; }
	_linux_focus "" "" ""
	[ ! -e "$BATS_TEST_TMPDIR/calls" ]
}

# ---------------------------------------------------------------------------
# _notify_alert
# ---------------------------------------------------------------------------

@test "_notify_alert: appends git branch to subtitle" {
	_load Linux
	_git_branch() { echo "feat/x"; }
	_os_send() { echo "$2" >"$BATS_TEST_TMPDIR/sub"; }
	_notify_alert "t" "Claude needs your input" ""
	[ "$(cat "$BATS_TEST_TMPDIR/sub")" = "Claude needs your input — feat/x" ]
}

@test "_notify_alert: leaves subtitle alone outside a git repo" {
	_load Linux
	_git_branch() { echo ""; }
	_os_send() { echo "$2" >"$BATS_TEST_TMPDIR/sub"; }
	_notify_alert "t" "Claude needs your input" ""
	[ "$(cat "$BATS_TEST_TMPDIR/sub")" = "Claude needs your input" ]
}

# ---------------------------------------------------------------------------
# _handle_event: suppression logic
# ---------------------------------------------------------------------------

@test "_handle_event: suppresses when terminal focused and no tmux" {
	_load
	_os_is_terminal_focused() { return 0; }
	_notify_alert() { echo "ALERT_CALLED"; }
	result="$(TMUX="" _handle_event)"
	[ -z "$result" ]
}

@test "_handle_event: suppresses when terminal focused and active tmux window" {
	_load
	_os_is_terminal_focused() { return 0; }
	_tmux_is_active_window() { return 0; }
	_notify_alert() { echo "ALERT_CALLED"; }
	result="$(TMUX="something" TMUX_PANE="%1" _handle_event)"
	[ -z "$result" ]
}

@test "_handle_event: sends alert when terminal not focused" {
	_load
	_os_is_terminal_focused() { return 1; }
	alert_sent=0
	_notify_alert() { alert_sent=1; }
	_project_name() { echo "owner/repo"; }
	_tmux_sound_enabled() { return 0; }
	_handle_event
	[ "$alert_sent" -eq 1 ]
}

@test "_handle_event: sends alert when terminal focused but different tmux window" {
	_load
	_os_is_terminal_focused() { return 0; }
	_tmux_is_active_window() { return 1; }
	alert_sent=0
	_notify_alert() { alert_sent=1; }
	_project_name() { echo "owner/repo"; }
	_tmux_sound_enabled() { return 0; }
	TMUX="something" TMUX_PANE="%1" _handle_event
	[ "$alert_sent" -eq 1 ]
}

@test "_handle_event: omits sound when sound disabled" {
	_load
	_os_is_terminal_focused() { return 1; }
	_project_name() { echo "myproject"; }
	_tmux_sound_enabled() { return 1; }
	captured_sound=""
	_notify_alert() { captured_sound="$3"; }
	_handle_event
	[ -z "$captured_sound" ]
}

@test "_handle_event: passes 'Ping' sound when sound enabled" {
	_load
	_os_is_terminal_focused() { return 1; }
	_project_name() { echo "myproject"; }
	_tmux_sound_enabled() { return 0; }
	captured_sound=""
	_notify_alert() { captured_sound="$3"; }
	_handle_event
	[ "$captured_sound" = "Ping" ]
}
