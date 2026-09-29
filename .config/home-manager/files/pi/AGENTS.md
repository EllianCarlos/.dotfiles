# Global instructions (pi)

## Labels

Do not label items with invented numbering codes like "A1, A2" or "Option 3" in
prose, plans, or summaries -- use descriptive names or plain lists. Only use
codes that are an industry standard (REQ1, FREQ1 for requirements) or a real
mathematical pointer (x1, x2, i, j).

## Read delegation

MUST delegate reading and summarizing files to the `scout` subagent (pinned
to google/gemini-3.6-flash) via the `subagent` tool, to keep reads on the
cheap path -- a direct read outside the exceptions below is a violation,
not a style choice. State exactly what to extract given your current goal
-- not "summarize this file."

The ONLY exceptions -- read the file yourself, in full, otherwise delegate:
- You are about to edit, refactor, or otherwise change it this turn.
- You are debugging and need to see exact code/output, not a summary.
- The user explicitly asked you to read/open/show its contents.

The gate is enforced MECHANICALLY, not just by this policy: the
pi-shunt-gate extension (modules/ai/shunt.nix) hands every read/bash call to
`shunt-check`, which blocks anything that would bring more than 350 lines of a
file into this session. It counts `sed -n`/`head`/`tail`/awk ranges and adds
up all slices of one file per session, so reconstructing a big file from
slices is blocked too. When it blocks, the fastest path is one bash call:
`bulk-read --question "<what you need>" --paths <file> [...]` (cheap model,
returns only the answer with path:line citations). Use `scout` when the job
needs several reading steps. For the exceptions above, look at the exact lines
you need with a bounded read of at most 80 lines.

Fallback order (TPM-aware): scout is pinned to google/gemini-3.6-flash
with a native `fallbackModels` chain (flash-latest -> 3.8-flash ->
live-preview, set in modules/ai/pi.nix) that pi-subagents walks on quota
failures; scout's own bounded read (≤350 lines/slice) is the terminal
fallback.

Memory saves (mnemon/engram) are local CLIs -- no model cost. pi-subagents
overrides can only repin builtin roles, so there is no dedicated scribe
agent here: scout is BOTH the read delegate AND the memory-save composition
delegate. Hand scout the save intent (mnemon = global/user fact, engram =
project fact); it drafts the payload and runs the CLI. Never compose a
save in the main session, and never feed a big raw file into the main
context just to write a memory.
