# Global Instructions

## Git commits

Do not add a `Co-Authored-By` trailer to git commit messages.

## Memory

Two complementary stores, split by SCOPE. Do not duplicate a fact across both.

- **mnemon** (global, cross-project): user preferences, decisions, identity, and
  cross-cutting facts that should follow you into every repo. Recent mnemon
  memories are AUTO-INJECTED each turn under `[mnemon:recall]` — read them as
  context. A blocking Stop gate makes you evaluate storing durable global facts
  before you end a turn (`mnemon remember`, via a sub-agent).
- **engram** (per-project working memory, MCP `mem_*`): bugfixes, architecture
  decisions, discoveries, conventions, and session handoffs scoped to THE CURRENT
  repo. Save proactively with `mem_save` after significant work — don't wait to be
  asked. After any compaction or context reset, first persist the injected summary
  with `mem_session_summary`, then request `mem_context` only if you need more.

Routing rule: a fact about the USER or spanning repos → mnemon. A fact about
THIS codebase/project → engram.

Never use the file-based `.md` memory system when mnemon/engram are active.

## Read delegation

MUST delegate reading and summarizing files to the `reader` subagent (Agent
tool, subagent_type="reader") to keep reads on the cheap path -- a direct
Read outside the exceptions below is a violation, not a style choice. State
exactly what to extract given your current goal -- not "summarize this
file." `reader` hands the read off to Gemini via `agy` (Google Antigravity
CLI, off the Anthropic plan entirely) and only falls back to reading it
itself on Haiku if `agy` is unavailable.

The ONLY exceptions -- read the file yourself, in full, otherwise delegate:
- You are about to edit, refactor, or otherwise change it this turn.
- You are debugging and need to see exact code/output, not a summary.
- The user explicitly asked you to read/open/show its contents.

This is the same routing model applied across opencode and pi in this
dotfiles repo (see files/opencode/AGENTS.md, files/pi/AGENTS.md) -- all three
harnesses land on google/gemini-3.6-flash as the cheap delegate; Claude Code
just reaches it via a subprocess (`agy`) instead of native cross-provider
subagents.

The gate is enforced MECHANICALLY, not just by this policy: a PreToolUse
hook (the "shunt" gate, modules/ai/shunt.nix) blocks Read/Bash calls that
would load a file bigger than 350 lines and tells you to delegate instead.
Don't fight it -- don't re-read in ≤350-line slices to reconstruct a big
file; that defeats the point. The same gate protects `cat`/`head`/`tail`
dumps on Bash.

## Fallback chain (when the cheap delegate hits its TPM ceiling)

Gemini models have per-day peak-TPM limits that differ per model tier. The
delegation path is ordered by TPM economics:

1. `gemini-flash-latest` -- highest peak TPM, serves bulk extraction
2. `gemini-3.8-flash` -> 3. `gemini-3.6-flash` -- mid chain
4. `gemini-3.1-flash-live-preview` -- low-TPM (~65k) floor; only ever sees
   the small extract question, never the file
5. Terminal fallback -- the reader subagent reads the file itself on Haiku
   in ≤350-line slices (only when the whole chain is exhausted)

For Claude Code this walk is automatic: `reader` calls `agy-shunt`, which
retries down the chain on quota/rate-limit errors. Never hand-retry `agy`
with a different --model.

## Memory saves (mnemon / engram)

The mnemon and engram CLIs are LOCAL (no model, no token cost) -- only
composing the save text costs tokens. ALL save composition and execution
goes through the dedicated `memory-scribe` subagent (Agent tool,
subagent_type="memory-scribe"): hand it the save intent + routing (mnemon =
global/user fact, engram = project fact); it drafts the payload, extracts
anything it needs from big files via the same shunt chain, runs the
`mnemon remember` / `engram save` CLI itself, and reports store + IDs.
Never compose a save in the main session, and never feed a big raw file
into the main context just to write a memory.
