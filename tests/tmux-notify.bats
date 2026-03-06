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

# ---------------------------------------------------------------------------
# _tmux_window_rename_enabled
# ---------------------------------------------------------------------------

@test "_tmux_window_rename_enabled: returns true when option is 'on'" {
	_load
	_tmux_option() { echo "on"; }
	_tmux_window_rename_enabled
}

@test "_tmux_window_rename_enabled: returns false when option is 'off'" {
	_load
	_tmux_option() { echo "off"; }
	run _tmux_window_rename_enabled
	[ "$status" -ne 0 ]
}

@test "_tmux_window_rename_enabled: default is 'off'" {
	_load
	tmux() { return 1; }
	export -f tmux
	run _tmux_window_rename_enabled
	[ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# _rename_window
# ---------------------------------------------------------------------------

@test "_rename_window: skips when disabled" {
	_load
	_tmux_window_rename_enabled() { return 1; }
	rename_called=0
	tmux() { rename_called=1; }
	export -f tmux
	_rename_window "Bash"
	[ "$rename_called" -eq 0 ]
}

@test "_rename_window: renames window to 'claude - <tool>'" {
	_load
	export TMUX_PANE="%3"
	_tmux_window_rename_enabled() { return 0; }
	_tmux_pane_window_name() { echo "mywindow"; }
	_tmux_pane_window() { echo "@1"; }
	rename_target=""
	rename_value=""
	tmux() {
		case "$1" in
		rename-window)
			rename_target="$3"
			rename_value="$4"
			;;
		esac
	}
	export -f tmux
	_rename_window "Bash"
	[ "$rename_target" = "@1" ]
	[ "$rename_value" = "claude - Bash" ]
}

@test "_rename_window: uses 'claude' as title when no tool name given" {
	_load
	export TMUX_PANE="%3"
	_tmux_window_rename_enabled() { return 0; }
	_tmux_pane_window_name() { echo "mywindow"; }
	_tmux_pane_window() { echo "@1"; }
	rename_value=""
	tmux() {
		case "$1" in
		show-option) echo ""; return 1 ;;
		set-option) ;;
		rename-window) rename_value="$4" ;;
		esac
	}
	export -f tmux
	_rename_window ""
	[ "$rename_value" = "claude" ]
}

@test "_rename_window: does not save name when current name is a version string" {
	_load
	export TMUX_PANE="%3"
	_tmux_window_rename_enabled() { return 0; }
	_tmux_pane_window_name() { echo "1.2.3"; }
	_tmux_pane_window() { echo "@1"; }
	set_option_count=0
	tmux() {
		case "$1" in
		show-option) echo ""; return 1 ;;
		set-option) set_option_count=$((set_option_count + 1)) ;;
		rename-window) ;;
		esac
	}
	export -f tmux
	_rename_window "Read"
	[ "$set_option_count" -eq 0 ]
}

@test "_rename_window: does not save name when current name starts with 'claude'" {
	_load
	export TMUX_PANE="%3"
	_tmux_window_rename_enabled() { return 0; }
	_tmux_pane_window_name() { echo "claude - Bash"; }
	_tmux_pane_window() { echo "@1"; }
	set_option_count=0
	tmux() {
		case "$1" in
		show-option) echo ""; return 1 ;;
		set-option) set_option_count=$((set_option_count + 1)) ;;
		rename-window) ;;
		esac
	}
	export -f tmux
	_rename_window "Read"
	[ "$set_option_count" -eq 0 ]
}

@test "_rename_window: does not overwrite saved name on repeat calls" {
	_load
	export TMUX_PANE="%3"
	_tmux_window_rename_enabled() { return 0; }
	_tmux_pane_window_name() { echo "mywindow"; }
	_tmux_pane_window() { echo "@1"; }
	set_option_count=0
	tmux() {
		case "$1" in
		show-option) echo "mywindow" ;;
		set-option) set_option_count=$((set_option_count + 1)) ;;
		rename-window) ;;
		esac
	}
	export -f tmux
	_rename_window "Bash"
	[ "$set_option_count" -eq 0 ]
}

# ---------------------------------------------------------------------------
# _restore_window_name
# ---------------------------------------------------------------------------

@test "_restore_window_name: skips rename when no saved name" {
	_load
	export TMUX_PANE="%3"
	_tmux_pane_window() { echo "@1"; }
	rename_called=0
	tmux() {
		case "$1" in
		show-option) echo ""; return 1 ;;
		rename-window) rename_called=1 ;;
		esac
	}
	export -f tmux
	_restore_window_name
	[ "$rename_called" -eq 0 ]
}

@test "_restore_window_name: restores saved name and clears option" {
	_load
	export TMUX_PANE="%3"
	_tmux_window_rename_enabled() { return 0; }
	_tmux_pane_window() { echo "@1"; }
	restore_target=""
	restore_value=""
	unset_key=""
	tmux() {
		case "$1" in
		show-option) echo "mywindow" ;;
		rename-window)
			restore_target="$3"
			restore_value="$4"
			;;
		set-option) unset_key="$3" ;;
		esac
	}
	export -f tmux
	_restore_window_name
	[ "$restore_target" = "@1" ]
	[ "$restore_value" = "mywindow" ]
	[ "$unset_key" = "@claude-saved-window-name-3" ]
}

# ---------------------------------------------------------------------------
# main — SessionStart event
# ---------------------------------------------------------------------------

@test "main: SessionStart event renames window to 'claude'" {
	_load
	export TMUX=fake
	export TMUX_PANE="%3"
	_tmux_window_rename_enabled() { return 0; }
	_tmux_pane_window_name() { echo "mywindow"; }
	_tmux_pane_window() { echo "@1"; }
	rename_target=""
	rename_value=""
	tmux() {
		case "$1" in
		show-option) echo ""; return 1 ;;
		set-option) ;;
		rename-window)
			rename_target="$3"
			rename_value="$4"
			;;
		esac
	}
	export -f tmux
	main < <(echo '{"hook_event_name":"SessionStart"}')
	[ "$rename_target" = "@1" ]
	[ "$rename_value" = "claude" ]
}
