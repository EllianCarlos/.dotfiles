---
title: Memory enrichment access paths
type: research
status: closed
assignee:
blocked_by: []
---

## Question

How can a non-interactive worker read engram and mnemon (CLI vs MCP vs direct DB), what query interfaces and output formats exist, and what do they offer for resolving a free-text prompt ("the cregit pipeline") to a project path and for assembling prior context? Also note how `memory-scribe` write-back is invoked outside a Claude Code session. Capture facts with sources.

## Resolution

Findings on branch `research/memory-enrichment-access-paths` (commit f1e2850, file `docs/wayfinder/pizza-delivery/research/memory-enrichment-access-paths.md`; throwaway, never merged).

- engram and mnemon are local CLIs over SQLite (WAL); both readable without a Claude session or MCP.
- mnemon: `recall`/`search`/`related`/`status` emit JSON; `--readonly` avoids writes (`recall` otherwise bumps access_count).
- engram: CLI `search`/`context` are text only; structured access via `engram export`, `engram serve` HTTP, `engram mcp`, or read-only SQLite.
- Repo resolution: engram `sessions.directory` is the best project-to-path index; plain `engram search` can pick the wrong project and project names are inconsistent. mnemon has no paths.
- `memory-scribe` is a Claude subagent file only; outside a session call `mnemon remember` / `engram save --project <canonical>` directly, or `claude -p --agent memory-scribe`.
- Unverified: engram HTTP read routes; mnemon `--readonly` access_count behaviour. (Subagent-reported; verify against the branch file.)
