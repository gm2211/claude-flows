#!/usr/bin/env bash
# SessionStart hook for claude-multiagent plugin

set -euo pipefail

# Determine plugin root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# --- Ensure beads-tui submodule and venv are ready ---
BEADS_TUI_DIR="${PLUGIN_ROOT}/scripts/beads-tui"
BEADS_TUI_VENV="${PLUGIN_ROOT}/scripts/.beads-tui-venv"

# Initialize git submodule if empty (only works in source checkout, not cache)
if [[ ! -d "${BEADS_TUI_DIR}/beads_tui" ]]; then
  _repo_root="$(cd "${PLUGIN_ROOT}" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$_repo_root" ]]; then
    git -C "$_repo_root" submodule update --init plugins/claude-multiagent/scripts/beads-tui 2>/dev/null || true
  fi
fi

# Create venv with textual if it doesn't exist (or is broken)
# Requires Python >=3.11 (beads-tui uses 3.10+ syntax like str | None)
if [[ ! -x "${BEADS_TUI_VENV}/bin/python3" ]] || ! "${BEADS_TUI_VENV}/bin/python3" -c "import textual" 2>/dev/null; then
  # Find a suitable Python >=3.11
  _py=""
  for _candidate_py in python3.13 python3.12 python3.11 python3; do
    if command -v "$_candidate_py" &>/dev/null; then
      _ver=$("$_candidate_py" -c "import sys; print(sys.version_info >= (3,11))" 2>/dev/null || echo "False")
      if [[ "$_ver" == "True" ]]; then
        _py="$(command -v "$_candidate_py")"
        break
      fi
    fi
  done
  # Also check common framework paths
  if [[ -z "$_py" ]]; then
    for _fwk in /Library/Frameworks/Python.framework/Versions/3.*/bin/python3; do
      if [[ -x "$_fwk" ]]; then
        _ver=$("$_fwk" -c "import sys; print(sys.version_info >= (3,11))" 2>/dev/null || echo "False")
        if [[ "$_ver" == "True" ]]; then _py="$_fwk"; break; fi
      fi
    done
  fi
  if [[ -n "$_py" ]]; then
    "$_py" -m venv "${BEADS_TUI_VENV}" 2>/dev/null || true
    if [[ -x "${BEADS_TUI_VENV}/bin/pip" ]]; then
      "${BEADS_TUI_VENV}/bin/pip" install --quiet textual 2>/dev/null || true
    fi
  fi
fi

# Export for open-dashboard.sh to use
export BEADS_TUI_VENV

# Escape string for JSON embedding using jq (much faster than bash parameter substitution).
escape_for_json() {
    jq -Rs . <<< "$1" | sed 's/^"//;s/"$//'
}

# --- Detect missing permissions in .claude/settings.local.json ---
SETTINGS_FILE="${PWD}/.claude/settings.local.json"
PERMISSIONS_MISSING=""

if [[ ! -f "$SETTINGS_FILE" ]]; then
  PERMISSIONS_MISSING="File ${SETTINGS_FILE} does not exist. All required settings are missing: sandbox.enabled, sandbox.autoAllowBashIfSandboxed, permissions.allow (Read, Edit, Write, Bash(bd:*), Bash(git:*)), env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS."
else
  _missing_parts=()

  # Check sandbox.enabled
  if ! jq -e '.sandbox.enabled == true' "$SETTINGS_FILE" &>/dev/null; then
    _missing_parts+=("sandbox.enabled must be true")
  fi

  # Check sandbox.autoAllowBashIfSandboxed
  if ! jq -e '.sandbox.autoAllowBashIfSandboxed == true' "$SETTINGS_FILE" &>/dev/null; then
    _missing_parts+=("sandbox.autoAllowBashIfSandboxed must be true")
  fi

  # Check each required permissions.allow entry
  for _perm in "Read" "Edit" "Write" 'Bash(bd:*)' 'Bash(git:*)'; do
    if ! jq -e --arg p "$_perm" '.permissions.allow // [] | index($p) != null' "$SETTINGS_FILE" &>/dev/null; then
      _missing_parts+=("permissions.allow missing \"${_perm}\"")
    fi
  done

  # Check env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS
  if ! jq -e '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS == "1"' "$SETTINGS_FILE" &>/dev/null; then
    _missing_parts+=("env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS must be \"1\"")
  fi

  # Build human-readable summary
  if [[ ${#_missing_parts[@]} -gt 0 ]]; then
    PERMISSIONS_MISSING=$(printf '%s\n' "${_missing_parts[@]}")
  fi
fi

# Build PERMISSIONS_BOOTSTRAP block for additionalContext if anything is missing
PERMISSIONS_BOOTSTRAP=""
if [[ -n "$PERMISSIONS_MISSING" ]]; then
  _bootstrap_block="<PERMISSIONS_BOOTSTRAP>
The following settings are missing or incorrect in ${SETTINGS_FILE}:

${PERMISSIONS_MISSING}

Recommended settings template (merge with any existing settings):

{
  \"permissions\": {
    \"allow\": [\"Read\", \"Edit\", \"Write\", \"Bash(bd:*)\", \"Bash(git:*)\"]
  },
  \"sandbox\": {
    \"enabled\": true,
    \"autoAllowBashIfSandboxed\": true
  },
  \"env\": {
    \"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS\": \"1\"
  }
}

Follow the Permissions Bootstrap procedure in your skill specification.
</PERMISSIONS_BOOTSTRAP>"
  PERMISSIONS_BOOTSTRAP="$(escape_for_json "$_bootstrap_block")\n"
fi

# Read multiagent-coordinator skill content
coordinator_content=$(cat "${PLUGIN_ROOT}/skills/multiagent-coordinator/SKILL.md" 2>&1 || echo "Error reading multiagent-coordinator skill")
coordinator_escaped=$(escape_for_json "$coordinator_content")

# Open Zellij dashboard panes (shared script; captures output to avoid
# breaking JSON on stdout). Any warnings (e.g. multi-session) are stored
# and relayed to the model via additionalContext.
dashboard_output=$("${PLUGIN_ROOT}/scripts/open-dashboard.sh" "${PWD}" 2>&1) || true

# Build the dashboard status note for the model
dashboard_note="The Zellij dashboard panes are already open."
if [[ -n "$dashboard_output" ]]; then
  dashboard_note="Dashboard script output: ${dashboard_output}"
fi
dashboard_note_escaped=$(escape_for_json "$dashboard_note")

# Output context injection as JSON
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "${PERMISSIONS_BOOTSTRAP}<EXTREMELY_IMPORTANT>\nYou are a COORDINATOR (claude-multiagent plugin). FORBIDDEN from editing files, writing code, running builds/tests/linters. Only git merges allowed. No exceptions. Dispatch sub-agents for all work. If task feels small, ask user via AskUserQuestion before doing it yourself.\n\nThe following is your complete behavioral specification. Every rule is mandatory.\n\n${coordinator_escaped}\n\n${dashboard_note_escaped}\n\nAcknowledge coordinator mode in your first response.\n</EXTREMELY_IMPORTANT>"
  }
}
EOF

exit 0
