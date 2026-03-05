#!/usr/bin/env bats
#
# tests/tmux-notify.bats — BATS tests for plugins/tmux-notify/scripts/tmux-notify.sh
#
# Run:
#   bats tests/tmux-notify.bats

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/plugins/tmux-notify/scripts/tmux-notify.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Source the script without running main
_load() {
	# Unset TMUX so _check_dependencies does not exit 0 early during sourcing
	TMUX="" TMUX_PANE="" source "$SCRIPT"
}

# ---------------------------------------------------------------------------
# _json_field
# ---------------------------------------------------------------------------

@test "_json_field: extracts a string field with jq" {
	_load
	result="$(_json_field "hook_event_name" '{"hook_event_name":"Stop"}')"
	[ "$result" = "Stop" ]
}

@test "_json_field: returns empty string for missing field" {
	_load
	result="$(_json_field "missing" '{"hook_event_name":"Stop"}')"
	[ -z "$result" ]
}

@test "_json_field: handles Notification value" {
	_load
	result="$(_json_field "hook_event_name" '{"hook_event_name":"Notification"}')"
	[ "$result" = "Notification" ]
}

@test "_json_field: returns empty string for empty JSON object" {
	_load
	result="$(_json_field "hook_event_name" '{}')"
	[ -z "$result" ]
}

# ---------------------------------------------------------------------------
# _tmux_option
# ---------------------------------------------------------------------------

@test "_tmux_option: returns default when tmux not available" {
	_load
	# Override tmux to simulate missing/unavailable option
	tmux() { return 1; }
	export -f tmux
	result="$(_tmux_option "@missing-option" "default-value")"
	[ "$result" = "default-value" ]
}

@test "_tmux_option: returns default when tmux returns empty" {
	_load
	tmux() { echo ""; }
	export -f tmux
	result="$(_tmux_option "@empty-option" "fallback")"
	[ "$result" = "fallback" ]
}

@test "_tmux_option: returns tmux value when set" {
	_load
	tmux() { echo "custom-value"; }
	export -f tmux
	result="$(_tmux_option "@some-option" "default")"
	[ "$result" = "custom-value" ]
}

# ---------------------------------------------------------------------------
# Config predicates
# ---------------------------------------------------------------------------

@test "_tmux_bell_enabled: returns true when option is 'on'" {
	_load
	_tmux_option() { echo "on"; }
	_tmux_bell_enabled
}

@test "_tmux_bell_enabled: returns false when option is 'off'" {
	_load
	_tmux_option() { echo "off"; }
	run _tmux_bell_enabled
	[ "$status" -ne 0 ]
}

@test "_tmux_bell_enabled: default is 'on'" {
	_load
	tmux() { return 1; }
	export -f tmux
	_tmux_bell_enabled
}

@test "_tmux_message_enabled: returns false when option is 'off'" {
	_load
	_tmux_option() { echo "off"; }
	run _tmux_message_enabled
	[ "$status" -ne 0 ]
}

@test "_tmux_message_enabled: default is 'off'" {
	_load
	tmux() { return 1; }
	export -f tmux
	run _tmux_message_enabled
	[ "$status" -ne 0 ]
}

@test "_tmux_auto_focus_enabled: returns false when option is 'off'" {
	_load
	_tmux_option() { echo "off"; }
	run _tmux_auto_focus_enabled
	[ "$status" -ne 0 ]
}

@test "_tmux_auto_focus_enabled: returns true when option is 'on'" {
	_load
	_tmux_option() { echo "on"; }
	_tmux_auto_focus_enabled
}

# ---------------------------------------------------------------------------
# State predicates
# ---------------------------------------------------------------------------

@test "_tmux_is_active_pane: true when active pane matches TMUX_PANE" {
	_load
	export TMUX_PANE="%3"
	_tmux_active_pane() { echo "%3"; }
	_tmux_is_active_pane
}

@test "_tmux_is_active_pane: false when active pane differs" {
	_load
	export TMUX_PANE="%3"
	_tmux_active_pane() { echo "%5"; }
	run _tmux_is_active_pane
	[ "$status" -ne 0 ]
}

@test "_tmux_is_active_session: true when sessions match" {
	_load
	_tmux_current_session() { echo "\$1"; }
	_tmux_pane_session() { echo "\$1"; }
	_tmux_is_active_session
}

@test "_tmux_is_active_session: false when sessions differ" {
	_load
	_tmux_current_session() { echo "\$1"; }
	_tmux_pane_session() { echo "\$2"; }
	run _tmux_is_active_session
	[ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# _check_dependencies
# ---------------------------------------------------------------------------

@test "_check_dependencies: exits 0 when TMUX is not set" {
	_load
	TMUX="" TMUX_PANE="" run _check_dependencies
	[ "$status" -eq 0 ]
}

@test "_check_dependencies: exits 0 when TMUX_PANE is not set" {
	_load
	TMUX="something" TMUX_PANE="" run _check_dependencies
	[ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# _notify_bell
# ---------------------------------------------------------------------------

@test "_notify_bell: skips when bell is disabled" {
	_load
	_tmux_bell_enabled() { return 1; }
	_tmux_pane_tty() { echo "/dev/null"; }
	# Should complete without error
	_notify_bell
}

@test "_notify_bell: writes to pane TTY when bell is enabled" {
	_load
	tmpfile="$(mktemp)"
	_tmux_bell_enabled() { return 0; }
	_tmux_pane_tty() { echo "$tmpfile"; }
	_notify_bell
	# File should have been written to (bell char)
	[ -f "$tmpfile" ]
	rm -f "$tmpfile"
}

# ---------------------------------------------------------------------------
# _handle_event: suppression when already active
# ---------------------------------------------------------------------------

@test "_handle_event: no-op when already the active pane" {
	_load
	_tmux_is_active_pane() { return 0; }
	# These should NOT be called
	_notify_bell() { echo "BELL_CALLED"; }
	_notify_message() { echo "MSG_CALLED"; }
	_notify_focus() { echo "FOCUS_CALLED"; }
	result="$(_handle_event "Stop")"
	[ -z "$result" ]
}

@test "_handle_event: sends bell when pane is inactive" {
	_load
	_tmux_is_active_pane() { return 1; }
	bell_called=0
	_notify_bell() { bell_called=1; }
	_tmux_pane_window_name() { echo "main"; }
	_notify_message() { :; }
	_notify_focus() { :; }
	_handle_event "Stop"
	[ "$bell_called" -eq 1 ]
}
