#!/usr/bin/env bash
# macos-focus.sh — activate terminal app and navigate to the tmux window
#
# Args:
#   $1 - path to tmux binary
#   $2 - tmux session name
#   $3 - tmux window id (e.g. @4)
#   $4 - tmux client tty (e.g. /dev/ttys001)
#   $5 - unix pid of the terminal app (optional; preferred over @claude-notify-terminal)

set -euo pipefail
[ -z "${DEBUG:-}" ] || set -x

TMUX_BIN="${1:-tmux}"
TMUX_SESSION="${2:-}"
TMUX_WINDOW="${3:-}"
TMUX_CLIENT="${4:-}"
TERMINAL_PID="${5:-}"

TERM_PROGRAM="$("$TMUX_BIN" show-option -gv "@claude-notify-terminal" 2>/dev/null || true)"

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Activate the terminal app
osascript "${SCRIPTS_DIR}/macos-focus.scpt" "$TERM_PROGRAM" "$TERMINAL_PID"

# Switch the tmux client to the correct window
if [[ -n "$TMUX_CLIENT" ]] && [[ -n "$TMUX_SESSION" ]] && [[ -n "$TMUX_WINDOW" ]]; then
	"$TMUX_BIN" switch-client -c "$TMUX_CLIENT" -t "${TMUX_SESSION}:${TMUX_WINDOW}"
fi
