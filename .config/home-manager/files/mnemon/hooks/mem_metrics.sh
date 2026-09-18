#!/usr/bin/env bash
# engram PostToolUse metrics -- token-cost proxy logging.
#
# Complements the recall/gate logging in user_prompt.sh and stop.sh: those
# two cover the automatic, unconditional per-turn hooks, this one covers
# every opt-in mcp__engram__* MCP call (mem_save, mem_judge, mem_search,
# mem_context, mem_update, ...), which also cost a tool-call round-trip plus
# (often large) JSON results. Logs bytes of the tool_response as a rough
# proxy (bytes/4 ~= tokens) -- see `mnemon-metrics`.
#
# Fails open: never blocks a tool call, matches how the other mnemon hooks
# degrade when a dependency is missing.
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

INPUT="$(cat)"
TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
[ -n "$TOOL" ] || exit 0

RESP_BYTES="$(printf '%s' "$INPUT" | jq -r '(.tool_response // {} | tostring) | length' 2>/dev/null)"

mkdir -p "${HOME}/.mnemon" 2>/dev/null
printf '%s\t%s\t%s\n' "$(date -u +%FT%TZ)" "$TOOL" "${RESP_BYTES:-0}" >>"${HOME}/.mnemon/metrics.log" 2>/dev/null

exit 0
