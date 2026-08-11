#!/usr/bin/env bash
# Claude Code status line.
# Reads the session JSON from stdin and prints one colorized line summarizing:
# model, repository, git branch, context usage (with a bar), 5h session
# usage (plus its reset countdown), 7-day weekly usage (plus its reset
# countdown), and elapsed session time.
#
# Icons are Nerd Font glyphs (Powerlevel10k, already in use by this user's
# zsh setup, requires one). If a glyph renders as a box/question mark, the
# terminal's font isn't a Nerd Font variant; swap ICON_* below for plain text.

input=$(cat)

RESET='\033[0m'
DIM='\033[2m'

C_MODEL='\033[38;5;81m'    # cyan   - model
C_REPO='\033[38;5;75m'     # blue   - repository
C_BRANCH='\033[38;5;170m'  # pink   - git branch
C_CTX='\033[38;5;114m'     # green  - context window usage
C_SESSION='\033[38;5;220m' # gold   - 5h session usage
C_WEEK='\033[38;5;208m'    # orange - 7d weekly usage
C_TIME='\033[38;5;245m'    # gray   - elapsed session time

ICON_MODEL=''   # nf-md-robot_outline
ICON_REPO=''    # nf-oct-repo
ICON_BRANCH=''  # nf-dev-git_branch
ICON_CTX=''     # nf-md-brain (context window)
ICON_SESSION=''  # nf-fa-clock_o (5h session usage)
ICON_WEEK=''    # nf-fa-calendar (7d weekly usage)
ICON_TIME=''     # nf-fa-hourglass_half (elapsed session time)

BAR_WIDTH=10
BAR_FILLED='█'
BAR_EMPTY='░'

# bar PCT -> prints a BAR_WIDTH-cell block bar for a 0-100 percentage.
bar() {
  local pct="$1"
  local filled
  filled=$(awk -v p="$pct" -v w="$BAR_WIDTH" 'BEGIN {
    if (p < 0) p = 0
    if (p > 100) p = 100
    printf "%d", int((p / 100.0) * w + 0.5)
  }')
  local empty=$((BAR_WIDTH - filled))
  local out=""
  local i
  for ((i = 0; i < filled; i++)); do out="${out}${BAR_FILLED}"; done
  for ((i = 0; i < empty; i++)); do out="${out}${BAR_EMPTY}"; done
  printf '%s' "$out"
}

# countdown EPOCH -> prints "<d>d<h>h" / "<h>h<m>m" / "<m>m" until EPOCH
# (whichever units are non-zero, largest first), empty if EPOCH is blank
# (rate_limits.*.resets_at is absent until the first API response of a
# session, same as used_percentage). The 7-day window's reset can be
# several days out, so days are included, unlike the elapsed-session timer.
countdown() {
  local epoch="$1"
  [ -z "$epoch" ] && return
  local now remaining days hrs mins
  now=$(date +%s)
  remaining=$((epoch - now))
  [ "$remaining" -lt 0 ] && remaining=0
  days=$((remaining / 86400))
  hrs=$(((remaining % 86400) / 3600))
  mins=$(((remaining % 3600) / 60))
  if [ "$days" -gt 0 ]; then
    printf '%dd%dh' "$days" "$hrs"
  elif [ "$hrs" -gt 0 ]; then
    printf '%dh%dm' "$hrs" "$mins"
  else
    printf '%dm' "$mins"
  fi
}

model=$(printf '%s' "$input" | jq -r '.model.display_name // empty')
cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty')

repo=$(printf '%s' "$input" | jq -r '.workspace.repo | if . then .owner + "/" + .name else empty end')
if [ -z "$repo" ] && [ -n "$cwd" ]; then
  repo=$(basename "$cwd")
fi

branch=""
if [ -n "$cwd" ] && git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
fi

ctx_used=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // 0')
five=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // 0')
week=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // 0')

five_resets_at=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week_resets_at=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
five_reset=$(countdown "$five_resets_at")
week_reset=$(countdown "$week_resets_at")

session_time=""
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty')
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  start_ts=$(head -n 1 "$transcript" 2>/dev/null | jq -r '.timestamp // empty' 2>/dev/null)
  if [ -n "$start_ts" ]; then
    start_epoch=$(date -d "$start_ts" +%s 2>/dev/null)
    now_epoch=$(date +%s)
    if [ -n "$start_epoch" ]; then
      elapsed=$((now_epoch - start_epoch))
      [ "$elapsed" -lt 0 ] && elapsed=0
      hrs=$((elapsed / 3600))
      mins=$(((elapsed % 3600) / 60))
      if [ "$hrs" -gt 0 ]; then
        session_time="${hrs}h${mins}m"
      else
        session_time="${mins}m"
      fi
    fi
  fi
fi

parts=()
[ -n "$model" ] && parts+=("${C_MODEL}${ICON_MODEL} ${model}${RESET}")
[ -n "$repo" ] && parts+=("${C_REPO}${ICON_REPO} ${repo}${RESET}")
[ -n "$branch" ] && parts+=("${C_BRANCH}${ICON_BRANCH} ${branch}${RESET}")
parts+=("${C_CTX}${ICON_CTX} ctx $(bar "$ctx_used") $(printf '%.0f' "$ctx_used")%${RESET}")
parts+=("${C_SESSION}${ICON_SESSION} 5h $(bar "$five") $(printf '%.0f' "$five")%${five_reset:+ ⟳${five_reset}}${RESET}")
parts+=("${C_WEEK}${ICON_WEEK} 7d $(bar "$week") $(printf '%.0f' "$week")%${week_reset:+ ⟳${week_reset}}${RESET}")
[ -n "$session_time" ] && parts+=("${C_TIME}${ICON_TIME} ${session_time}${RESET}")

out=""
for i in "${!parts[@]}"; do
  if [ "$i" -eq 0 ]; then
    out="${parts[$i]}"
  else
    out="${out} ${DIM}|${RESET} ${parts[$i]}"
  fi
done

printf '%b\n' "$out"
