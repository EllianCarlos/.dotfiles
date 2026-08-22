#!/usr/bin/env bash
# PostToolUse hook (Edit|Write matcher): catch broken JSON/Nix syntax right
# after the edit lands, instead of discovering it at the next rebuild.
# PostToolUse can't undo a completed tool call, so exit 2 here doesn't block
# anything -- it just routes the stderr message back to the model (exit 0
# would only show it in the human-facing transcript) so it can self-correct.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[ -z "$FILE_PATH" ] && exit 0
[ -f "$FILE_PATH" ] || exit 0

case "$FILE_PATH" in
  *.json|*.jsonc)
    if ! jq . "$FILE_PATH" >/dev/null 2>&1; then
      echo "[validate-config] INVALID JSON: $FILE_PATH" >&2
      exit 2
    fi
    ;;
  *.nix)
    if ! nix-instantiate --parse "$FILE_PATH" >/dev/null 2>&1; then
      echo "[validate-config] INVALID NIX: $FILE_PATH" >&2
      exit 2
    fi
    ;;
esac

exit 0
