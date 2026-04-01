# Sandbox Companion Agent Generator

Generate a locked-down, file-based RPC script that lets Claude trigger specific operations on the host machine when those operations can't run inside the sandbox.

## When to use

When a tool, CLI, or runtime doesn't work inside the Claude Code sandbox (broken compiler, missing credentials, network restrictions, platform-specific binaries) and needs to run on the host instead.

## What you produce

A single self-locking shell script that:
1. Watches a command file for instructions from Claude
2. Maps command keywords to hardcoded invocations (no arguments, no eval, no shell expansion)
3. Sanitizes all input to `[a-z-]` only
4. Writes output to a result file Claude can read
5. On first run, detects its own permissions and locks itself down (`chmod 444`, `chown root:wheel/root`)

## Process

### Step 1: Understand the problem

Ask the user:
- What tool/operation doesn't work in the sandbox?
- What specific invocations do you need? (e.g., `doctl compute droplet list`, `cargo check`, `terraform plan`)
- Where should the script live?

### Step 2: Generate the script

Use this template structure:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENT_DIR="$SCRIPT_DIR/.companion_agent"
COMMAND_FILE="$AGENT_DIR/command"
RESULT_FILE="$AGENT_DIR/result"
STATUS_FILE="$AGENT_DIR/status"
PID_FILE="$AGENT_DIR/agent.pid"

# ──────────────────────────────────────────────
# Self-lockdown: runs once on first invocation
# ──────────────────────────────────────────────
lockdown() {
    local perms owner
    perms=$(stat -f "%OLp" "$SCRIPT_PATH" 2>/dev/null || stat -c "%a" "$SCRIPT_PATH" 2>/dev/null)
    owner=$(stat -f "%Su" "$SCRIPT_PATH" 2>/dev/null || stat -c "%U" "$SCRIPT_PATH" 2>/dev/null)

    if [[ "$perms" != "444" || "$owner" != "root" ]]; then
        echo "[companion] This script is not locked down yet."
        echo "[companion] Locking: chmod 444 + chown root"
        echo ""

        # Detect OS for correct group
        if [[ "$(uname)" == "Darwin" ]]; then
            sudo chown root:wheel "$SCRIPT_PATH"
        else
            sudo chown root:root "$SCRIPT_PATH"
        fi
        sudo chmod 444 "$SCRIPT_PATH"

        echo "[companion] Locked. Re-run with: bash $SCRIPT_PATH"
        exit 0
    fi
}

# ──────────────────────────────────────────────
# Command definitions — EDIT THIS SECTION
# Each case maps a keyword to an exact invocation.
# No arguments from the command file ever reach these.
# ──────────────────────────────────────────────
run_command() {
    case "$1" in
        # example-list)
        #     doctl compute droplet list --format ID,Name,PublicIPv4,Status 2>&1
        #     ;;
        # example-check)
        #     cargo check 2>&1
        #     ;;
        *)
            echo "ERROR: Unknown command '$1'"
            echo "Available: <list your commands here>"
            return 1
            ;;
    esac
}

# ──────────────────────────────────────────────
# Core loop — do not modify below this line
# ──────────────────────────────────────────────
cleanup() {
    rm -f "$PID_FILE"
    echo "stopped" > "$STATUS_FILE"
    echo "[companion] Stopped."
    exit 0
}
trap cleanup EXIT INT TERM

lockdown

mkdir -p "$AGENT_DIR"
echo $$ > "$PID_FILE"
echo "idle" > "$STATUS_FILE"
: > "$COMMAND_FILE"
: > "$RESULT_FILE"

echo "[companion] Running in $SCRIPT_DIR"
echo "[companion] Waiting for commands..."
echo ""

while true; do
    if [[ -s "$COMMAND_FILE" ]]; then
        CMD=$(head -1 "$COMMAND_FILE" | tr -d '[:space:]' | tr -cd 'a-z-')
        : > "$COMMAND_FILE"

        if [[ -z "$CMD" ]]; then
            continue
        fi

        echo "[companion] Received: $CMD"
        echo "running" > "$STATUS_FILE"

        (
            cd "$SCRIPT_DIR"
            run_command "$CMD"
            echo ""
            echo "EXIT_CODE=$?"
        ) > "$RESULT_FILE" 2>&1

        echo "done" > "$STATUS_FILE"
        echo "[companion] Done."
    fi
    sleep 0.5
done
```

### Step 3: Customize

Replace the `run_command()` cases with the exact invocations the user needs. Rules:
- **Every command is a single keyword** mapped to a hardcoded invocation
- **Never pass arguments** from the command file to the invocation
- **Never use `eval`**, backticks, or `$(...)` with user input
- **Always `2>&1`** to capture stderr in the result file

### Step 4: Instruct the user

Tell the user to:
1. Copy the script to the target directory
2. Run it once: `bash <script>.sh` — it will self-lock (chmod 444, chown root) and exit
3. Run it again: `bash <script>.sh` — now it runs the watch loop
4. Add `.companion_agent/` to `.gitignore`

### Step 5: Claude usage

To invoke a command from the sandbox:
```bash
echo "<command-keyword>" > /path/to/.companion_agent/command
```

To wait for completion:
```bash
while [ "$(cat /path/to/.companion_agent/status)" = "running" ]; do sleep 3; done
cat /path/to/.companion_agent/result
```

## Security properties

- Input sanitized to `[a-z-]` — no metacharacters, no injection
- Fixed enum of commands — no arbitrary execution
- No eval, no argument passing, no shell expansion
- Script owned by root, mode 444 — Claude cannot modify it
- Self-locking on first run — user doesn't need to remember chmod/chown steps

## Anti-patterns to avoid

- Do NOT expose generic commands like `npm run` (runs arbitrary scripts)
- Do NOT accept arguments or flags from the command file
- Do NOT use `eval` anywhere
- Do NOT expose filesystem utilities (ls, cat, rm) — Claude can do those locally
- Do NOT skip the lockdown step