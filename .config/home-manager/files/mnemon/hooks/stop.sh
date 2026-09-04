#!/usr/bin/env bash
# mnemon Stop hook -- BLOCKING CAPTURE GATE.
#
# Claude Code ignores stdout reminders (audit 2026-08-15: 7 recalls, 0
# remembers in a day), but it CANNOT ignore a Stop hook that exits 2 -- that
# blocks the stop and feeds stderr back as a directive the model must act on.
# So this hook forces the store decision exactly once per turn.
#
# Loop-safe: Claude sets stop_hook_active=true on the re-entry after we block,
# and we exit 0 then. We also exit 0 when a memory write already happened this
# turn, or when jq is unavailable (we cannot read the guard flag, so we must
# never block -- an unguarded exit 2 would loop forever).
set -uo pipefail

INPUT="$(cat)"

# No jq -> cannot read stop_hook_active -> must not block. Degrade to a
# plain (ignorable) reminder rather than risk an infinite stop loop.
if ! command -v jq >/dev/null 2>&1; then
  echo "[mnemon] Before ending: if this turn produced a durable fact, decision, preference, or correction, store it -- mnemon remember (global) or engram mem_save (project-scoped)."
  exit 0
fi

STOP_ACTIVE="$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)"
[ "$STOP_ACTIVE" = "true" ] && exit 0

# If a memory write already landed in the recent transcript tail, capture is
# done for this turn -- don't nag.
TRANSCRIPT="$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)"
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  if tail -n 300 "$TRANSCRIPT" 2>/dev/null | grep -qE 'mnemon remember|mem_save'; then
    exit 0
  fi
fi

# Block once and make the model decide, explicitly, before it may stop.
cat >&2 <<'EOF'
[mnemon] STOP GATE -- evaluate the memory decision tree before ending this turn:
  - Durable USER / cross-project fact, preference, decision, or correction
    -> store with the mnemon remember sub-agent (global memory).
  - Fact, bugfix, or decision scoped to THIS repo/codebase
    -> store with engram mem_save (project memory).
If genuinely nothing is worth storing, say so in one line, then stop.
Do not stop silently.
EOF
exit 2

