# Sandbox Companion Agent Generator

Generate a locked-down, file-based RPC script that lets Claude trigger specific operations on the host machine when those operations can't run inside the Claude Code sandbox.

## When to use

When a tool, CLI, credential store, or runtime doesn't work inside the sandbox (missing Keychain access, missing binaries, platform-specific tooling, network restrictions, Docker daemon quirks) and needs to run on the host instead.

This skill generalizes to **any project** — it asks the user what commands they need and generates a project-specific script.

## What you produce

A single self-locking shell script at `<project-root>/companion.sh` (or a user-chosen path) that:

1. Watches a command queue directory for instructions from Claude
2. Maps command keywords to hardcoded invocations (no arguments, no eval, no shell expansion)
3. Sanitizes all input to `[a-z-]` only
4. Writes output to a result file Claude can read
5. On first run, self-locks: `chown root`, `chmod 444`, and sets the OS immutable flag (`chflags schg` on macOS / `chattr +i` on Linux) so Claude cannot tamper with it via Write/Edit/shell

## Process

### Step 1: Understand what the user needs

Ask the user:

- **What project / working directory** is the companion for?
- **What specific invocations** do you need? (e.g. `./deploy.sh`, `cargo check`, `terraform plan`, `kubectl get pods`)
- **Anything privileged** — reads from Keychain, requires sudo, uses cloud creds?

Keep the command set small and purpose-built. One keyword per operation. No generic escape hatches.

### Step 2: Generate the script

Use this exact template structure. Fill in the `run_command()` cases with what the user asked for — never expose generic runners like `bash`, `npm run`, `make`, `eval`.

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENT_DIR="$SCRIPT_DIR/.companion_agent"
QUEUE_DIR="$AGENT_DIR/queue"
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
        echo "[companion] Locking: chmod 444 + chown root + immutable flag"
        echo "[companion] You will be prompted for sudo."
        echo ""

        if [[ "$(uname)" == "Darwin" ]]; then
            sudo chown root:wheel "$SCRIPT_PATH"
        else
            sudo chown root:root "$SCRIPT_PATH"
        fi
        sudo chmod 444 "$SCRIPT_PATH"

        # CRITICAL: immutable flag blocks unlink, not just open-for-write.
        # Claude's Write tool does unlink+create; without schg/+i, Write
        # would succeed even on a 444 root-owned file (if the parent dir
        # is user-writable, which it usually is).
        if [[ "$(uname)" == "Darwin" ]]; then
            sudo chflags schg "$SCRIPT_PATH"
        else
            sudo chattr +i "$SCRIPT_PATH" 2>/dev/null || true
        fi

        mkdir -p "$QUEUE_DIR"
        echo "[companion] Locked (immutable). Re-run with: bash $SCRIPT_PATH"
        exit 0
    fi
}

# ──────────────────────────────────────────────
# Command definitions — FILL IN FOR THIS PROJECT
# Each keyword maps to an exact invocation.
# No arguments from the command file ever reach these.
# ──────────────────────────────────────────────
run_command() {
    case "$1" in
        # example-deploy)
        #     ./deploy.sh -auto-approve 2>&1
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
# Unlock: restore write permissions for editing
# Usage: bash companion.sh unlock
# ──────────────────────────────────────────────
unlock() {
    local target_user="${SUDO_USER:-$USER}"
    echo "[companion] Unlocking for editing..."

    if [[ "$(uname)" == "Darwin" ]]; then
        sudo chflags noschg "$SCRIPT_PATH" 2>/dev/null || true
        sudo chown "$target_user:staff" "$SCRIPT_PATH"
    else
        sudo chattr -i "$SCRIPT_PATH" 2>/dev/null || true
        sudo chown "$target_user:$target_user" "$SCRIPT_PATH"
    fi
    sudo chmod 644 "$SCRIPT_PATH"
    echo "[companion] Unlocked. Edit the script, then run again to re-lock."
    exit 0
}

# ──────────────────────────────────────────────
# Core loop — do not modify below this line
# ──────────────────────────────────────────────
cleanup() {
    rm -f "$PID_FILE"
    echo "stopped" > "$STATUS_FILE" 2>/dev/null || true
    echo "[companion] Stopped."
    exit 0
}
trap cleanup EXIT INT TERM

case "${1:-}" in
    unlock) unlock ;;
esac

lockdown

mkdir -p "$QUEUE_DIR"
echo $$ > "$PID_FILE"
echo "idle" > "$STATUS_FILE"
: > "$RESULT_FILE"

echo "[companion] Running in $SCRIPT_DIR"
echo "[companion] Waiting for commands..."
echo ""

while true; do
    NEXT=$(find "$QUEUE_DIR" -name '*.cmd' -type f 2>/dev/null | sort | head -1)
    if [[ -n "$NEXT" ]]; then
        CMD=$(head -1 "$NEXT" | tr -d '[:space:]' | tr -cd 'a-z-')
        rm -f "$NEXT"

        [[ -z "$CMD" ]] && continue

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
    else
        sleep 0.5
    fi
done
```

### Step 3: Customize the `run_command()` cases

Fill in the cases with the user's specific operations. Rules:

- **Single keyword → hardcoded invocation.** Keywords are `[a-z-]` only.
- **Never pass arguments** from the queue file to the invocation.
- **Never use `eval`**, backticks, or `$(...)` with user-controlled input.
- **Always `2>&1`** so stderr lands in the result file.
- **Use `|| true`** sparingly — usually you want non-zero exits surfaced.

Example (adapt to the project):

```bash
run_command() {
    case "$1" in
        deploy)       ./deploy.sh -auto-approve 2>&1 ;;
        deploy-plan)  terraform -chdir=deploy plan 2>&1 ;;
        status)       kubectl -n myapp get pods,svc,ingress 2>&1 ;;
        logs)         kubectl -n myapp logs -l app=api --tail=200 2>&1 ;;
        git-push)     git push 2>&1 ;;
        *)
            echo "ERROR: Unknown command '$1'"
            echo "Available: deploy, deploy-plan, status, logs, git-push"
            return 1
            ;;
    esac
}
```

### Step 4: Verify the lockdown

After writing the script and having the user run it to self-lock, **test that Claude cannot tamper with it** (this is important — do it before trusting the companion):

1. Try `Edit` — should fail with `EPERM`
2. Try `Write` — should fail with `EPERM` (Write unlinks first; schg blocks unlink)
3. Try shell overwrite `> companion.sh` — should fail
4. Try `rm companion.sh` — should fail
5. Try `mv companion.sh /tmp/stolen.sh` — should fail

If any of these succeed, the lockdown is broken — investigate before using the companion.

### Step 5: Instruct the user

```
1. I've written companion.sh at <path>.
2. Run it once to self-lock:        bash companion.sh
   (prompts sudo; chmod 444, chown root, chflags schg, then exits)
3. Run it again to start the loop:  bash companion.sh
   Leave it running in a terminal.
4. Add to .gitignore:               .companion_agent/
5. To edit later:                   bash companion.sh unlock
   (removes immutable flag; then re-run to re-lock)
```

### Step 6: How Claude invokes commands

Drop a command file in the queue:

```bash
echo "<keyword>" > /path/to/project/.companion_agent/queue/$(date +%s%N).cmd
```

Wait for it to finish and read the result:

```bash
while [ -n "$(ls /path/to/project/.companion_agent/queue/*.cmd 2>/dev/null)" ] || \
      [ "$(cat /path/to/project/.companion_agent/status)" = "running" ]; do
    sleep 1
done
cat /path/to/project/.companion_agent/result
```

For long-running commands (deploys, builds), poll `status` less aggressively — `sleep 5` is fine.

## Security properties

- **Fixed enum of commands** — no arbitrary execution, no generic runners
- **Input sanitized to `[a-z-]`** — no metacharacters, no path traversal, no injection
- **No eval, no argument passing, no shell expansion** of queue content
- **Script is root-owned, mode 444, immutable** (`schg`/`+i`) — Claude's Write/Edit tools and shell all fail with `EPERM`; `rm` and `mv` also fail because unlink is blocked
- **Spool queue directory** — each command is a separate timestamped file, preventing rapid-fire overwrites and providing audit trail
- **Self-locking on first run** — user doesn't need to remember chmod/chown/chflags steps
- **Unlock command** — `bash script.sh unlock` cleanly removes the flag for legitimate edits

## Anti-patterns to avoid

- Do NOT expose generic commands like `npm run <x>`, `make <target>`, `bash <file>` — these run arbitrary code chosen by Claude.
- Do NOT accept arguments or flags from the command file — keywords only.
- Do NOT use `eval` anywhere in the script.
- Do NOT expose filesystem utilities (`ls`, `cat`, `rm`, `find`) — Claude can do those locally in the sandbox.
- Do NOT skip the lockdown step or the schg/+i immutable flag — without it, `Write` succeeds on a user-writable parent dir.
- Do NOT use a single-file `echo > command` pattern — commands are lost under rapid-fire usage; always use a spool queue with timestamped files.
- Do NOT forget `2>&1` — stderr must land in the result file.
- Do NOT commit `.companion_agent/` — it contains transient state and potentially sensitive output.
