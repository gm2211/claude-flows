#!/usr/bin/env bash
# Launcher script for watch-dashboard.
# Uses the managed venv from BEADS_TUI_VENV (shared with beads-tui).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WATCH_DASHBOARD_DIR="${SCRIPT_DIR}/watch_dashboard"

# Find a Python with textual installed
_venv="${BEADS_TUI_VENV:-}"
if [[ -n "$_venv" && -x "${_venv}/bin/python3" ]]; then
    PYTHON="${_venv}/bin/python3"
elif command -v python3 &>/dev/null; then
    PYTHON=python3
else
    echo "Error: python3 not found" >&2
    exit 1
fi

exec env PYTHONPATH="${SCRIPT_DIR}:${PYTHONPATH:-}" "$PYTHON" -m watch_dashboard "$@"
