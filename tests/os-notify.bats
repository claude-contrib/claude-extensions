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
# Linux backend: _os_send / _os_is_terminal_focused
# ---------------------------------------------------------------------------

@test "linux _os_is_terminal_focused: always false (no focus detection yet)" {
	_load Linux
	run _os_is_terminal_focused
	[ "$status" -ne 0 ]
}

@test "linux _os_send: calls notify-send with title and body after --" {
	_load Linux
	notify-send() { printf '%s\n' "$@" >"$BATS_TEST_TMPDIR/args"; }
	_os_send "owner/repo" "needs input" "Ping"
	[ "$(tail -n 2 "$BATS_TEST_TMPDIR/args")" = "$(printf 'owner/repo\nneeds input')" ]
	grep -qx -- "--" "$BATS_TEST_TMPDIR/args"
	grep -qx "string:sound-name:message-new-instant" "$BATS_TEST_TMPDIR/args"
}

@test "linux _os_send: omits sound hint when sound is empty" {
	_load Linux
	notify-send() { printf '%s\n' "$@" >"$BATS_TEST_TMPDIR/args"; }
	_os_send "t" "b" ""
	! grep -q "sound-name" "$BATS_TEST_TMPDIR/args"
}

@test "linux _os_send: title starting with a dash is not parsed as an option" {
	_load Linux
	notify-send() { printf '%s\n' "$@" >"$BATS_TEST_TMPDIR/args"; }
	_os_send "-evil" "b" ""
	[ "$(grep -nx -- '--' "$BATS_TEST_TMPDIR/args" | cut -d: -f1)" -lt "$(grep -nx -- '-evil' "$BATS_TEST_TMPDIR/args" | cut -d: -f1)" ]
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
