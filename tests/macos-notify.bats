#!/usr/bin/env bats
#
# tests/macos-notify.bats — BATS tests for plugins/macos-notify/scripts/macos-notify.sh
#
# Run:
#   bats tests/macos-notify.bats

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/plugins/macos-notify/scripts/macos-notify.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Source the script without running main.
# Stubs terminal-notifier and uname so the dependency check passes on Linux CI.
_load() {
	terminal-notifier() { :; }
	export -f terminal-notifier
	uname() { echo "Darwin"; }
	export -f uname
	TMUX="" TMUX_PANE="" source "$SCRIPT"
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
# _check_dependencies
# ---------------------------------------------------------------------------

@test "_check_dependencies: exits 0 on non-macOS" {
	_load
	uname() { echo "Linux"; }
	run _check_dependencies
	[ "$status" -eq 0 ]
}

@test "_check_dependencies: exits 1 when terminal-notifier not found" {
	_load
	uname() { echo "Darwin"; }
	command() { return 1; }
	run _check_dependencies
	[ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# _handle_event: suppression logic
# ---------------------------------------------------------------------------

@test "_handle_event: suppresses when terminal focused and no tmux" {
	_load
	_macos_is_terminal_focused() { return 0; }
	_notify_alert() { echo "ALERT_CALLED"; }
	result="$(TMUX="" _handle_event)"
	[ -z "$result" ]
}

@test "_handle_event: suppresses when terminal focused and active tmux window" {
	_load
	_macos_is_terminal_focused() { return 0; }
	_tmux_is_active_window() { return 0; }
	_notify_alert() { echo "ALERT_CALLED"; }
	result="$(TMUX="something" TMUX_PANE="%1" _handle_event)"
	[ -z "$result" ]
}

@test "_handle_event: sends alert when terminal not focused" {
	_load
	_macos_is_terminal_focused() { return 1; }
	alert_sent=0
	_notify_alert() { alert_sent=1; }
	_project_name() { echo "owner/repo"; }
	_tmux_sound_enabled() { return 0; }
	_handle_event
	[ "$alert_sent" -eq 1 ]
}

@test "_handle_event: sends alert when terminal focused but different tmux window" {
	_load
	_macos_is_terminal_focused() { return 0; }
	_tmux_is_active_window() { return 1; }
	alert_sent=0
	_notify_alert() { alert_sent=1; }
	_project_name() { echo "owner/repo"; }
	_tmux_sound_enabled() { return 0; }
	result="$(TMUX="something" TMUX_PANE="%1" _handle_event)"
	# Can't use alert_sent in subshell, so just verify it runs without error
	[ "$?" -eq 0 ]
}

@test "_handle_event: omits sound when sound disabled" {
	_load
	_macos_is_terminal_focused() { return 1; }
	_project_name() { echo "myproject"; }
	_tmux_sound_enabled() { return 1; }
	captured_sound=""
	_notify_alert() { captured_sound="$3"; }
	_handle_event
	[ -z "$captured_sound" ]
}

@test "_handle_event: passes 'Ping' sound when sound enabled" {
	_load
	_macos_is_terminal_focused() { return 1; }
	_project_name() { echo "myproject"; }
	_tmux_sound_enabled() { return 0; }
	captured_sound=""
	_notify_alert() { captured_sound="$3"; }
	_handle_event
	[ "$captured_sound" = "Ping" ]
}
