#!/usr/bin/env bash
# focus.sh — activate terminal app and navigate to the tmux window
#
# Args:
#   $1 - path to tmux binary
#   $2 - tmux session name
#   $3 - tmux window name
#   $4 - tmux client tty (e.g. /dev/ttys001)

set -euo pipefail

TMUX_BIN="${1:-tmux}"
TMUX_SESSION="${2:-}"
TMUX_WINDOW="${3:-}"
TMUX_CLIENT="${4:-}"

TERM_PROGRAM="$("$TMUX_BIN" show-option -gv "@claude-notify-term-program" 2>/dev/null || echo "ghostty")"

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Activate the terminal app
osascript "${SCRIPTS_DIR}/focus.scpt" "$TERM_PROGRAM"

# Switch the tmux client to the correct window
if [[ -n "$TMUX_CLIENT" ]] && [[ -n "$TMUX_SESSION" ]] && [[ -n "$TMUX_WINDOW" ]]; then
  "$TMUX_BIN" switch-client -c "$TMUX_CLIENT" -t "${TMUX_SESSION}:${TMUX_WINDOW}"
fi
