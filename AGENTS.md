# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get started.

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
bd sync               # Sync with git
```

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
- **Bump plugin version** on every commit that changes plugin files. Update BOTH `plugins/claude-multiagent/.claude-plugin/plugin.json` AND `.claude-plugin/marketplace.json` (keep versions in sync). Use semver: patch for fixes, minor for features, major for breaking changes. Without a version bump, `/plugin` update won't pick up changes.

## Worktree Convention

When the coordinator dispatches you with REPO_ROOT and EPIC_BRANCH:
1. `cd $REPO_ROOT`
2. `git worktree add .worktrees/${EPIC_BRANCH}--<your-task-slug> -b ${EPIC_BRANCH}--<your-task-slug>`
3. `cd .worktrees/${EPIC_BRANCH}--<your-task-slug>`
4. Do all work in this worktree
5. Commit and push your branch when done
