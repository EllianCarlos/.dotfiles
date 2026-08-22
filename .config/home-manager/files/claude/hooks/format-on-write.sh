#!/usr/bin/env bash
# PostToolUse hook (Edit|MultiEdit|Write matcher): after Claude changes a
# file, hand it to the formatter script below. That script owns the
# decision of which files it formats and skips the rest -- this hook does
# no filtering of its own.
#
# FORMATTER currently points at the local stub (special-black.py). Once
# the real repo ships, swap it for the skill-deployed copy instead:
#   1. Pin the repo in pins.nix (owner/repo/rev), like the other sources.
#   2. Add it to skills.nix's `sources` so it deploys under ~/.claude/skills/.
#   3. Point FORMATTER at $HOME/.claude/skills/<skill-name>/scripts/<script>.py
#      and delete hooks/special-black.py + its home.file entry in home.nix --
#      the skill-deployed copy replaces the stub, it doesn't sit next to it.
# Never hand-edit the skill-deployed copy: `agent-skills-nix` re-syncs
# ~/.claude/skills/** with `rsync --delete` on every rebuild, so any fix
# has to land in the upstream repo (or your fork) and get re-pinned here.
#
# PostToolUse can't undo a completed tool call, so a formatting failure
# here can't block the edit. The hook itself never blocks Claude either:
# the inspect+clean work runs in a detached background job, and the hook
# returns right away. Trade-off: because the hook exits before that job
# finishes, it can no longer route a clean failure back to Claude via
# stderr + exit 2 -- Claude's turn is already over by then. Failures go
# to LOG_FILE instead; check it by hand if a file looks unclean.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[ -z "$FILE_PATH" ] && exit 0
[ -f "$FILE_PATH" ] || exit 0

SCRIPTS="$HOME/.claude/skills/remove-ai-marks/scripts"
[ -x "$SCRIPTS" ] || exit 0
INSPECT_FILE="$SCRIPTS/inspect_file.py"
# Skill scripts deploy read-only from the nix store (no exec bit); we run
# them through `python3`, so only readability matters here, not -x.
[ -r "$INSPECT_FILE" ] || exit 0
CLEAN_FILE="$SCRIPTS/clean_file.py"
[ -r "$CLEAN_FILE" ] || exit 0

LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude"
LOG_FILE="$LOG_DIR/format-on-write.log"
mkdir -p "$LOG_DIR"

(
  {
    # inspect_file.py exits 1 when it finds marks -- that is its normal
    # "marks found" result, not a crash, so its exit code must not gate
    # the clean step below. It runs here only to log a before-picture.
    echo "[watermarks-remover] $(date -Iseconds) inspect for $FILE_PATH:"
    python3 "$INSPECT_FILE" "$FILE_PATH" 2>&1

    if ! OUTPUT=$(python3 "$CLEAN_FILE" "$FILE_PATH" -o "$FILE_PATH" 2>&1); then
      echo "[watermarks-remover] clean file failed for $FILE_PATH:"
      echo "$OUTPUT"
    fi
  } >>"$LOG_FILE" 2>&1
) &
disown

exit 0
