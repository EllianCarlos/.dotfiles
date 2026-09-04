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
