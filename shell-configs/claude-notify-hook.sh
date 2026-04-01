#!/usr/bin/env bash
# claude-notify-hook.sh — Claude Code hook that signals zellij-attention
#
# Called by PreToolUse/PostToolUse hooks. Reads JSON from stdin.
# In sandbox: writes to ~/.claude/notify/signal (bridge forwards to zellij)
# On host: calls zellij pipe directly
set -euo pipefail

EVENT="${1:?Usage: claude-notify-hook.sh <event> where event=waiting|completed|question}"
SIGNAL_DIR="$HOME/.claude/notify"
SIGNAL_FILE="$SIGNAL_DIR/signal"

# If ZELLIJ_PANE_ID is set AND we're not in a Docker sandbox,
# pipe directly to zellij. Otherwise write to signal file for the bridge.
if [ -n "${ZELLIJ_PANE_ID:-}" ] && [ ! -f "/.dockerenv" ]; then
    zellij pipe --name "zellij-attention::${EVENT}::${ZELLIJ_PANE_ID}" 2>/dev/null || true
else
    mkdir -p "$SIGNAL_DIR"
    echo "$EVENT" > "$SIGNAL_FILE"
fi
