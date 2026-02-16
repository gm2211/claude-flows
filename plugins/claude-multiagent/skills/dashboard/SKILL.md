---
name: dashboard
description: Reopen the Zellij dashboard panes (tickets + agent status) if you closed them
---

# Reopen Dashboard Panes

Run these commands to restore the dashboard panes. Requires Zellij.

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/claude-multiagent}"
zellij action new-pane --direction right -- bash -c "cd '$(pwd)' && '${PLUGIN_ROOT}/scripts/watch-beads.sh'"
zellij action new-pane --direction down -- bash -c "cd '$(pwd)' && '${PLUGIN_ROOT}/scripts/watch-agents.sh'"
zellij action move-focus left
```

## Safety Rules

**ONLY** use `new-pane` and `move-focus` Zellij actions. **NEVER** use `close-pane`, `close-tab`, or `go-to-tab`.
