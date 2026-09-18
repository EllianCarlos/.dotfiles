# Global instructions (opencode)

## Labels

Do not label items with invented numbering codes like "A1, A2" or "Option 3" in
prose, plans, or summaries -- use descriptive names or plain lists. Only use
codes that are an industry standard (REQ1, FREQ1 for requirements) or a real
mathematical pointer (x1, x2, i, j).

## Read delegation

MUST delegate reading and summarizing files to the `reader` agent (model:
google/gemini-3.6-flash) via the task tool, to keep reads on the cheap path
-- a direct read outside the exceptions below is a violation, not a style
choice. State exactly what to extract given your current goal -- not
"summarize this file."

The ONLY exceptions -- read the file yourself, in full, otherwise delegate:
- You are about to edit, refactor, or otherwise change it this turn.
- You are debugging and need to see exact code/output, not a summary.
- The user explicitly asked you to read/open/show its contents.

This applies to every agent and persona running in this opencode install,
including oh-my-opencode's dynamic personas (Sisyphus, Hephaestus, Metis,
Momus, Oracle, Prometheus, Atlas/Ultraworker, etc.) -- there is no exception
by agent identity, only by task shape (the three cases above).

The gate is enforced MECHANICALLY, not just by this policy: the shunt-gate
plugin (modules/ai/shunt.nix) blocks Read/Bash calls that would load a file
bigger than 350 lines and points you at `reader`. Don't fight it and don't
reconstruct big files from ≤350-line slices.

Fallback order (TPM-aware): reader is pinned to google/gemini-3.6-flash.
If its task calls fail on quota/TPM errors, retry the delegation via
`local-qwen` (ollama, local, no TPM ceiling) -- that is the terminal
fallback of the chain. `small_model` (titles/background work) is separately
pinned to the low-TPM google/gemini-flash-lite-latest.

Memory saves (mnemon/engram) are local CLIs -- no model cost -- but save
composition MUST go through the dedicated `memory-scribe` subagent (task
tool, agent "memory-scribe"): hand it the save intent + routing (mnemon =
global/user fact, engram = project fact); it drafts the payload, runs the
local memory CLI itself, and reports store + IDs back. Never compose a
save in the main session, and never feed a big raw file into the main
context just to write a memory.
