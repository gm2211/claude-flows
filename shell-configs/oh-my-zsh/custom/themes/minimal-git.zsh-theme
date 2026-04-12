# Minimal Git Theme
# Shows: time, directory, git branch, worktree, changed files, additions, deletions

_git_info() {
  local branch worktree changed additions deletions info=""

  branch=$(git symbolic-ref --short HEAD 2>/dev/null) || return
  info="%F{magenta}${branch}%f"

  # Worktree: show if in a linked worktree
  local git_dir=$(git rev-parse --git-dir 2>/dev/null)
  if [[ "$git_dir" == *".git/worktrees/"* ]]; then
    local wt_name="${git_dir:t}"
    info+=" %F{cyan}[wt:${wt_name}]%f"
  fi

  # Stats from git diff (staged + unstaged combined)
  local stat=$(git diff HEAD --shortstat 2>/dev/null)
  local untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')

  if [[ -n "$stat" || "$untracked" -gt 0 ]]; then
    changed=$(echo "$stat" | sed -E 's/.* ([0-9]+) file.*/\1/')
    additions=$(echo "$stat" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+')
    deletions=$(echo "$stat" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+')

    [[ -n "$stat" ]] && info+=" %F{yellow}~${changed:-0}%f"
    [[ -n "$stat" ]] && info+=" %F{green}+${additions:-0}%f"
    [[ -n "$stat" ]] && info+=" %F{red}-${deletions:-0}%f"
    [[ "$untracked" -gt 0 ]] && info+=" %F{white}?${untracked}%f"
  fi

  echo " ${info}"
}

setopt PROMPT_SUBST

PROMPT='%F{8}%*%f %F{blue}%~%f$(_git_info) %F{white}❯%f '
