#!/bin/bash
# Watches .agent-status.md and renders a pretty Unicode table
# Uses fswatch for efficient event-driven updates, falls back to polling

# Force UTF-8 for Unicode box-drawing characters
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# Hide cursor; restore on exit
trap 'tput cnorm 2>/dev/null; exit' INT TERM EXIT
tput civis 2>/dev/null

elapsed_since() {
  local start="$1"
  if ! [[ "$start" =~ ^[0-9]+$ ]]; then
    printf '%s' "$start"
    return
  fi
  local now diff
  now=$(date +%s)
  diff=$(( now - start ))
  if [ $diff -lt 60 ]; then
    printf '%ds' "$diff"
  elif [ $diff -lt 3600 ]; then
    printf '%dm %ds' "$(( diff / 60 ))" "$(( diff % 60 ))"
  else
    printf '%dh %dm' "$(( diff / 3600 ))" "$(( (diff % 3600) / 60 ))"
  fi
}

# Parse a status file that may be TSV or Markdown table format.
# Outputs clean TSV lines (one per row, header first).
parse_status_file() {
  local file="$1"

  # Detect format: scan for any line containing a pipe character
  local is_markdown=false
  while IFS= read -r probe; do
    if [[ "$probe" == *$'\t'* ]]; then
      # Contains a tab -- TSV format
      break
    fi
    if [[ "$probe" == *"|"* ]]; then
      is_markdown=true
      break
    fi
  done < "$file"

  if $is_markdown; then
    while IFS= read -r line; do
      # Skip blank lines and non-table lines (e.g. "=== Agent Status ===")
      [[ -z "$line" ]] && continue
      [[ "$line" != *"|"* ]] && continue
      # Skip markdown separator rows like |---|---|
      if [[ "$line" =~ ^[[:space:]]*\|[-[:space:]|]+\|[[:space:]]*$ ]]; then
        continue
      fi
      # Strip leading/trailing whitespace
      line="${line#"${line%%[![:space:]]*}"}"
      line="${line%"${line##*[![:space:]]}"}"
      # Strip leading/trailing pipes
      line="${line#|}"
      line="${line%|}"
      # Split on |, trim each cell, rejoin with tabs
      local out=""
      local IFS='|'
      local -a parts
      read -ra parts <<< "$line"
      for part in "${parts[@]}"; do
        part="${part#"${part%%[![:space:]]*}"}"
        part="${part%"${part##*[![:space:]]}"}"
        [ -n "$out" ] && out+=$'\t'
        out+="$part"
      done
      printf '%s\n' "$out"
    done < "$file"
  else
    # Already TSV -- pass through non-empty lines
    while IFS= read -r line; do
      [[ -n "$line" ]] && printf '%s\n' "$line"
    done < "$file"
  fi
}

render_table() {
  local file="$1"
  local -a lines
  local -a widths
  local ncols=0
  local duration_col=-1
  local term_width
  term_width=$(tput cols 2>/dev/null || printf '80')

  # Read parsed lines, resolve Duration/Started column timestamps
  local line_idx=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if [ $line_idx -eq 0 ]; then
      IFS=$'\t' read -ra hdr <<< "$line"
      for ((c=0; c<${#hdr[@]}; c++)); do
        if [ "${hdr[$c]}" = "Started" ]; then
          duration_col=$c
        fi
      done
      line="${line/Started/Duration}"
    elif [ $duration_col -ge 0 ]; then
      IFS=$'\t' read -ra cells <<< "$line"
      cells[$duration_col]=$(elapsed_since "${cells[$duration_col]}")
      local joined=""
      for ((c=0; c<${#cells[@]}; c++)); do
        [ $c -gt 0 ] && joined+=$'\t'
        joined+="${cells[$c]}"
      done
      line="$joined"
    fi
    lines+=("$line")
    ((line_idx++))
  done < <(parse_status_file "$file")

  [ ${#lines[@]} -eq 0 ] && return

  # Calculate column widths
  for line in "${lines[@]}"; do
    IFS=$'\t' read -ra cells <<< "$line"
    local i=0
    for cell in "${cells[@]}"; do
      local len=${#cell}
      if [ $i -ge $ncols ]; then
        ncols=$((i + 1))
        widths[$i]=0
      fi
      [ $len -gt ${widths[$i]:-0} ] && widths[$i]=$len
      ((i++))
    done
  done

  [ $ncols -eq 0 ] && return

  # Add 2-char padding per column
  for ((i=0; i<ncols; i++)); do
    widths[$i]=$(( ${widths[$i]} + 2 ))
  done

  # Shrink columns if table exceeds terminal width
  # Total width = sum(widths) + ncols + 1  (for the vertical bars)
  local total=0
  for ((i=0; i<ncols; i++)); do total=$(( total + widths[i] )); done
  total=$(( total + ncols + 1 ))
  local min_col=5  # minimum column width (3 content + 2 padding)
  if [ $total -gt $term_width ] && [ $ncols -gt 0 ]; then
    local excess=$(( total - term_width ))
    # Iteratively shrink the widest column by 1 until we fit
    while [ $excess -gt 0 ]; do
      # Find the widest shrinkable column
      local widest=-1 widest_w=0
      for ((i=0; i<ncols; i++)); do
        if [ ${widths[$i]} -gt $min_col ] && [ ${widths[$i]} -gt $widest_w ]; then
          widest=$i
          widest_w=${widths[$i]}
        fi
      done
      [ $widest -lt 0 ] && break  # nothing left to shrink
      widths[$widest]=$(( widths[$widest] - 1 ))
      excess=$(( excess - 1 ))
    done
  fi

  # Helper: repeat a character N times
  repchar() { printf '%*s' "$2" '' | tr ' ' "$1"; }

  # Build horizontal borders
  local top_border mid_border bot_border
  top_border="┌"
  mid_border="├"
  bot_border="└"
  for ((i=0; i<ncols; i++)); do
    local bar
    bar=$(repchar "─" "${widths[$i]}")
    if [ $i -lt $((ncols-1)) ]; then
      top_border+="${bar}┬"
      mid_border+="${bar}┼"
      bot_border+="${bar}┴"
    else
      top_border+="${bar}┐"
      mid_border+="${bar}┤"
      bot_border+="${bar}┘"
    fi
  done

  printf '%s\n' "$top_border"

  local row_idx=0
  for line in "${lines[@]}"; do
    IFS=$'\t' read -ra cells <<< "$line"
    local row="│"
    for ((i=0; i<ncols; i++)); do
      local cell="${cells[$i]:-}"
      local w=${widths[$i]}
      local len=${#cell}
      # Truncate cell if it exceeds available space inside the column
      local max_content=$(( w - 2 ))
      if [ $max_content -lt 1 ]; then max_content=1; fi
      if [ $len -gt $max_content ]; then
        if [ $max_content -ge 3 ]; then
          cell="${cell:0:$((max_content - 2))}.."
        else
          cell="${cell:0:$max_content}"
        fi
        len=${#cell}
      fi
      if [ $row_idx -eq 0 ]; then
        # Center-align headers
        local pad=$(( (w - len) / 2 ))
        local rpad=$(( w - len - pad ))
        printf -v row '%s%*s%s%*s│' "$row" "$pad" '' "$cell" "$rpad" ''
      else
        # Left-align data with 1-space left padding
        local rpad=$(( w - len - 1 ))
        printf -v row '%s %s%*s│' "$row" "$cell" "$rpad" ''
      fi
    done
    printf '%s\n' "$row"
    if [ $row_idx -eq 0 ]; then
      printf '%s\n' "$mid_border"
    fi
    ((row_idx++))
  done

  printf '%s\n' "$bot_border"
}

resolve_status_file() {
  if [ -f ".agent-status.md" ]; then
    printf '%s' ".agent-status.md"
  elif [ -f "$HOME/.claude/agent-status.md" ]; then
    printf '%s' "$HOME/.claude/agent-status.md"
  fi
}

FIRST_RENDER=true

render_screen() {
  if $FIRST_RENDER; then
    clear
    FIRST_RENDER=false
  else
    # Move cursor to top-left and clear screen from there -- flicker-free
    tput cup 0 0 2>/dev/null
    tput ed 2>/dev/null
  fi

  local status_file
  status_file=$(resolve_status_file)
  printf 'Agent Status\n\n'
  if [ -n "$status_file" ] && [ -f "$status_file" ]; then
    render_table "$status_file"
  else
    printf '  No agents running.\n'
  fi
  printf '\nUpdated %s\n' "$(date '+%H:%M:%S')"
}

# Initial render
render_screen

if command -v fswatch &>/dev/null; then
  # Event-driven: watch both possible locations, re-render on change
  # --latency 0.5: debounce rapid writes
  # --one-per-batch: single event per batch of changes
  fswatch --latency 0.5 --one-per-batch \
    ".agent-status.md" "$HOME/.claude/agent-status.md" 2>/dev/null \
  | while read -r _; do
    render_screen
  done
  # fswatch exited (e.g. neither file exists yet) -- fall through to polling
fi

# Fallback: poll every 5s (also used while waiting for status file to appear)
while true; do
  sleep 5
  render_screen
done
