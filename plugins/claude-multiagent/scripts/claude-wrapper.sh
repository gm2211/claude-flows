#!/usr/bin/env bash
# claude-wrapper.sh — Worktree-first launcher for Claude Code.
#
# This script sits on PATH before the real `claude` binary. It prevents
# Claude Code sessions from accidentally working on the default branch
# (main/master) of a git repo. When it detects that situation, it offers
# to create or select a worktree before launching Claude inside it.
#
# Installation:
#   Symlink this script as `claude` somewhere earlier in your PATH than
#   the real claude binary. For example:
#     ln -sf /path/to/claude-wrapper.sh ~/.local/bin/claude
#
# Pass-through cases (no intervention):
#   - Not inside a git repository
#   - Already inside a git worktree
#   - On a non-default branch (not main/master)
#
# Target case (on main/master in a repo root):
#   - Lists existing epic worktrees in .worktrees/
#   - Offers to create a new worktree with an AI-generated branch name
#   - Launches the real claude from inside the chosen worktree

set -euo pipefail

###############################################################################
# Helpers
###############################################################################

msg()  { printf '%s\n' "$*" >&2; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
err()  { printf 'ERROR: %s\n' "$*" >&2; }

# Clean up on Ctrl+C
trap 'msg ""; msg "Interrupted."; exit 130' INT

###############################################################################
# Find the real claude binary (skip ourselves)
###############################################################################

SELF="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"

find_real_claude() {
  # Iterate over PATH entries to find a `claude` that is not this script
  local IFS=':'
  for dir in $PATH; do
    local candidate="$dir/claude"
    [ -x "$candidate" ] || continue

    # Resolve the candidate to its real path
    local resolved
    resolved="$(realpath "$candidate" 2>/dev/null || readlink -f "$candidate" 2>/dev/null || echo "$candidate")"

    if [ "$resolved" != "$SELF" ]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

REAL_CLAUDE="$(find_real_claude)" || {
  err "Could not find the real claude binary in PATH."
  err "Make sure claude is installed and this wrapper is not the only 'claude' on PATH."
  exit 1
}

###############################################################################
# Case 1: Not a git repo → pass through
###############################################################################

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exec "$REAL_CLAUDE" "$@"
fi

###############################################################################
# Case 2: Already in a worktree → pass through
###############################################################################

GIT_DIR="$(git rev-parse --git-dir 2>/dev/null)"
GIT_COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null)"

# Normalize to absolute paths for reliable comparison
ABS_GIT_DIR="$(cd "$GIT_DIR" && pwd)"
ABS_GIT_COMMON="$(cd "$GIT_COMMON_DIR" && pwd)"

if [ "$ABS_GIT_DIR" != "$ABS_GIT_COMMON" ]; then
  exec "$REAL_CLAUDE" "$@"
fi

###############################################################################
# Case 3: On a non-default branch → pass through
###############################################################################

# Detect the default branch dynamically
DEFAULT_BRANCH="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')"
if [ -z "$DEFAULT_BRANCH" ]; then
  # Fallback: check if main or master exists
  if git show-ref --verify --quiet refs/heads/main 2>/dev/null; then
    DEFAULT_BRANCH="main"
  elif git show-ref --verify --quiet refs/heads/master 2>/dev/null; then
    DEFAULT_BRANCH="master"
  else
    DEFAULT_BRANCH="main"
  fi
fi

CURRENT_BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || echo "")"

if [ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]; then
  exec "$REAL_CLAUDE" "$@"
fi

###############################################################################
# Case 4: On default branch in a git repo — offer worktree selection/creation
###############################################################################

REPO_ROOT="$(git rev-parse --show-toplevel)"
WORKTREES_DIR="$REPO_ROOT/.worktrees"
mkdir -p "$WORKTREES_DIR"

msg ""
msg "You are on the '$DEFAULT_BRANCH' branch. Claude should run in a worktree."
msg ""

# Collect existing epic worktrees (directories without -- in their name)
EPIC_WORKTREES=()
if [ -d "$WORKTREES_DIR" ]; then
  for wt_dir in "$WORKTREES_DIR"/*/; do
    [ -d "$wt_dir" ] || continue
    wt_name="$(basename "$wt_dir")"
    # Skip task worktrees (contain --)
    case "$wt_name" in *--*) continue ;; esac
    EPIC_WORKTREES+=("$wt_name")
  done
fi

CHOICE=""

if [ ${#EPIC_WORKTREES[@]} -gt 0 ]; then
  msg "Existing worktrees:"
  for i in "${!EPIC_WORKTREES[@]}"; do
    msg "  $((i + 1))) ${EPIC_WORKTREES[$i]}"
  done
  msg "  n) Create new worktree"
  msg ""

  read -r -p "Select a worktree [1-${#EPIC_WORKTREES[@]}/n]: " selection </dev/tty >&2

  if [ "$selection" = "n" ] || [ "$selection" = "N" ]; then
    CHOICE="__new__"
  elif [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#EPIC_WORKTREES[@]} ]; then
    CHOICE="${EPIC_WORKTREES[$((selection - 1))]}"
  else
    err "Invalid selection: $selection"
    exit 1
  fi
else
  CHOICE="__new__"
fi

###############################################################################
# Create new worktree
###############################################################################

if [ "$CHOICE" = "__new__" ]; then
  read -r -p "What are you working on? (short description): " description </dev/tty >&2

  if [ -z "$description" ]; then
    err "Description cannot be empty."
    exit 1
  fi

  # Try to generate a branch name using claude -p
  BRANCH_NAME=""
  msg "Generating branch name..."

  BRANCH_NAME=$("$REAL_CLAUDE" -p "Generate a short kebab-case branch name (max 30 chars, no prefix) for this feature: ${description}. Output ONLY the branch name, nothing else." 2>/dev/null) || true

  # Clean up the response: trim whitespace, remove quotes, take first line only
  BRANCH_NAME="$(echo "$BRANCH_NAME" | head -1 | tr -d '[:space:]"'\'' ' | tr -cd 'a-z0-9-')"

  # Fallback if claude -p failed or returned empty/garbage
  if [ -z "$BRANCH_NAME" ] || [ "${#BRANCH_NAME}" -gt 40 ]; then
    warn "Could not generate branch name automatically. Please provide one."
    read -r -p "Branch name (kebab-case, max 30 chars): " BRANCH_NAME </dev/tty >&2

    if [ -z "$BRANCH_NAME" ]; then
      err "Branch name cannot be empty."
      exit 1
    fi

    # Sanitize user input
    BRANCH_NAME="$(echo "$BRANCH_NAME" | tr '[:upper:]' '[:lower:]' | tr ' _' '--' | tr -cd 'a-z0-9-' | sed -E 's/-+/-/g; s/^-+//; s/-+$//' | cut -c1-30)"
  fi

  WORKTREE_PATH="$WORKTREES_DIR/$BRANCH_NAME"

  # If this worktree already exists, just use it
  if [ -d "$WORKTREE_PATH" ]; then
    msg "Worktree '$BRANCH_NAME' already exists. Using it."
    CHOICE="$BRANCH_NAME"
  else
    msg "Creating worktree: $BRANCH_NAME"
    git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" || {
      err "Failed to create worktree. You may need to resolve this manually."
      exit 1
    }
    CHOICE="$BRANCH_NAME"
  fi
fi

###############################################################################
# Launch claude from inside the chosen worktree
###############################################################################

TARGET_DIR="$WORKTREES_DIR/$CHOICE"

if [ ! -d "$TARGET_DIR" ]; then
  err "Worktree directory does not exist: $TARGET_DIR"
  exit 1
fi

msg ""
msg "Launching Claude in worktree: $CHOICE"
msg ""

cd "$TARGET_DIR"
exec "$REAL_CLAUDE" "$@"
