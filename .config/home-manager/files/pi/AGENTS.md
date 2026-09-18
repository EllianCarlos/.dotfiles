# Global instructions (pi)

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
pi-shunt-gate extension (modules/ai/shunt.nix) blocks Read/Bash calls that
would load a file bigger than 350 lines and points you at `scout`. Don't
fight it and don't reconstruct big files from ≤350-line slices.

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
