#!/usr/bin/env bash
# clauded-notify-bridge.sh — host-side watcher that translates Docker container
# notification signals into host zellij tab icon updates.
#
# Usage: clauded-notify-bridge.sh <ZELLIJ_PANE_ID>
#
# The container's activity hook writes "waiting", "completed", or "clear" to
# ~/.claude/notify/signal. This script polls that file and sends the
# corresponding zellij pipe commands to update the host zellij tab icons.
#
# Started automatically by clauded() in the background. Exits when the signal
# dir is removed or the parent zellij pane no longer exists.

set -euo pipefail

PANE_ID="${1:?Usage: clauded-notify-bridge.sh <ZELLIJ_PANE_ID>}"
SIGNAL_DIR="$HOME/.claude/notify"
SIGNAL_FILE="$SIGNAL_DIR/signal"
POLL_INTERVAL=2  # seconds

# Ensure signal dir exists
mkdir -p "$SIGNAL_DIR"

cleanup() {
    zellij pipe --name "zellij-attention::completed::$PANE_ID" 2>/dev/null || true
    rm -f "$SIGNAL_FILE" 2>/dev/null
    exit 0
}
trap cleanup EXIT INT TERM

while true; do
    # Exit if not inside zellij anymore
    if [ -z "${ZELLIJ:-}" ]; then
        break
    fi

    # Atomically consume the signal file: move then read, so no signal is
    # lost or deduplicated away.  Fast tools may overwrite the file between
    # polls, but we always process the latest state.
    if [ -f "$SIGNAL_FILE" ]; then
        tmp="$SIGNAL_FILE.$$"
        if mv "$SIGNAL_FILE" "$tmp" 2>/dev/null; then
            signal=$(cat "$tmp" 2>/dev/null || true)
            rm -f "$tmp"
            case "$signal" in
                waiting)
                    zellij pipe --name "zellij-attention::waiting::$PANE_ID" 2>/dev/null || true
                    ;;
                question)
                    zellij pipe --name "zellij-attention::question::$PANE_ID" 2>/dev/null || true
                    ;;
                completed|clear)
                    zellij pipe --name "zellij-attention::completed::$PANE_ID" 2>/dev/null || true
                    ;;
            esac
        fi
    fi

    sleep "$POLL_INTERVAL"
done
