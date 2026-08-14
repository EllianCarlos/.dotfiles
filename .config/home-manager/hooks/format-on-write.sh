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
# here can't block the edit. It only routes stderr back to the model
# (exit 2) so Claude sees it and can react.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[ -z "$FILE_PATH" ] && exit 0
[ -f "$FILE_PATH" ] || exit 0

SCRIPTS="$HOME/.claude/skills/remove-ai-marks/scripts"
[ -x "$SCRIPTS" ] || exit 0
INSPECT_FILE="$SCRIPTS/inspect_file.py"
[ -x "$INSPECT_FILE" ] || exit 0
CLEAN_FILE="$SCRIPTS/clean_file.py"
[ -x "$CLEAN_FILE" ] || exit 0

if ! OUTPUT=$(python3 "$INSPECT_FILE" "$FILE_PATH" 2>&1); then
  echo "[watermarks-remover] inspect failed for $FILE_PATH:" >&2
  echo "$OUTPUT" >&2
  exit 2
fi

if ! OUTPUT=$(python3 "$CLEAN_FILE" "$FILE_PATH" -o "$FILE_PATH" 2>&1); then
  echo "[watermarks-remover] clean file failed for $FILE_PATH:" >&2
  echo "$OUTPUT" >&2
  exit 2
fi

exit 0
