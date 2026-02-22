#!/usr/bin/env bash
# Pre-push hook: validates semantic versioning for plugin files.
# Install: ln -sf <path-to-this-script> .git/hooks/pre-push
# Skip: git push --no-verify
set -euo pipefail

# Find the latest semver tag
LATEST_TAG=$(git tag --sort=-v:refname | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)

if [[ -z "$LATEST_TAG" ]]; then
  # No semver tags yet — nothing to validate against
  exit 0
fi

# Check if any plugin files changed since the last tag
CHANGED_FILES=$(git diff --name-only "$LATEST_TAG"..HEAD 2>/dev/null || true)

if ! echo "$CHANGED_FILES" | grep -q '^plugins/'; then
  # No plugin files changed — nothing to validate
  exit 0
fi

# Plugin files changed — check version bump
PLUGIN_JSON="plugins/claude-multiagent/.claude-plugin/plugin.json"
MARKETPLACE_JSON=".claude-plugin/marketplace.json"

# Get current versions
CURRENT_PLUGIN_VER=""
CURRENT_MARKET_VER=""
if [[ -f "$PLUGIN_JSON" ]]; then
  CURRENT_PLUGIN_VER=$(jq -r '.version // empty' "$PLUGIN_JSON" 2>/dev/null || true)
fi
if [[ -f "$MARKETPLACE_JSON" ]]; then
  CURRENT_MARKET_VER=$(jq -r '.plugins[0].version // empty' "$MARKETPLACE_JSON" 2>/dev/null || true)
fi

# Get tagged versions
TAGGED_PLUGIN_VER=$(git show "$LATEST_TAG:$PLUGIN_JSON" 2>/dev/null | jq -r '.version // empty' 2>/dev/null || true)
TAGGED_MARKET_VER=$(git show "$LATEST_TAG:$MARKETPLACE_JSON" 2>/dev/null | jq -r '.plugins[0].version // empty' 2>/dev/null || true)

# Validate
ERRORS=()

if [[ -n "$TAGGED_PLUGIN_VER" && "$CURRENT_PLUGIN_VER" == "$TAGGED_PLUGIN_VER" ]]; then
  ERRORS+=("plugin.json version ($CURRENT_PLUGIN_VER) not bumped since $LATEST_TAG")
fi

if [[ -n "$TAGGED_MARKET_VER" && "$CURRENT_MARKET_VER" == "$TAGGED_MARKET_VER" ]]; then
  ERRORS+=("marketplace.json version ($CURRENT_MARKET_VER) not bumped since $LATEST_TAG")
fi

if [[ -n "$CURRENT_PLUGIN_VER" && -n "$CURRENT_MARKET_VER" && "$CURRENT_PLUGIN_VER" != "$CURRENT_MARKET_VER" ]]; then
  ERRORS+=("Version mismatch: plugin.json=$CURRENT_PLUGIN_VER, marketplace.json=$CURRENT_MARKET_VER")
fi

if [[ ${#ERRORS[@]} -gt 0 ]]; then
  echo ""
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║  PRE-PUSH: Semantic version validation failed       ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo ""
  for err in "${ERRORS[@]}"; do
    echo "  ✖ $err"
  done
  echo ""
  echo "  Plugin files changed since $LATEST_TAG but version was not bumped."
  echo "  Bump version in both files, commit, then push again."
  echo ""
  echo "  To skip: git push --no-verify"
  echo ""
  exit 1
fi

exit 0
