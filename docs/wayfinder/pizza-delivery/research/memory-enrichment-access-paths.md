# Memory enrichment access paths (engram + mnemon)

Ticket: `docs/wayfinder/pizza-delivery/tickets/memory-enrichment-access-paths.md`.
Method: primary sources only, observed on this host on 2026-11-09 (`engram --help`, `mnemon <cmd> --help`,
live CLI calls, read-only SQLite schema dumps, `~/.claude/agents/memory-scribe.md`, `~/.mnemon/prompt/*.md`, `claude --help`).
Versions: engram v1.20.0 (the CLI prints "update available 3.7.0"); mnemon version not captured.

## Summary

- Both tools are plain local CLIs over SQLite files. A worker needs no Claude Code session and no MCP to read or write either.
- mnemon is the better fit for programmatic reads: commands print JSON, `--readonly` exists, and recall is graph/entity aware.
- engram's CLI read output is human text (no `--json` on `search`/`context`); structured access means the HTTP API (`engram serve`), the MCP server, `engram export`, or direct read-only SQLite.
- For mapping "the cregit pipeline" to a repo path: engram `sessions.directory` stores an absolute working directory per project, the most direct project-to-path index. mnemon has entities but no paths unless a memory states one.
- `memory-scribe` is only a Claude Code subagent prompt (haiku; tools Bash/Read/Grep/Glob). Outside Claude Code, write-back is either `engram save` / `mnemon remember` called directly, or `claude -p --agent memory-scribe`.

## engram

### Storage layout
- Data dir `~/.engram` (override `ENGRAM_DATA_DIR`): `engram.db` plus WAL files. SQLite in WAL mode, so a read-only second connection is safe while another process writes.
- Tables (from `sqlite_master`): `sessions(id, project, directory, started_at, ended_at, summary)`, `observations(id, sync_id, session_id, type, title, content, tool_name, project, scope, topic_key, normalized_hash, revision_count, ...)`, `observations_fts` (FTS5 over title, content, tool_name, type, project, topic_key), `user_prompts` (+`prompts_fts`), `memory_relations` (conflict judgments), plus sync/cloud tables.
- Live state: 131 observations, 10 sessions, 9 project names; only scope seen is `project`.
- Caveat: project names are not canonical. Both `.dotfiles` (69 obs) and `dotfiles` (17 obs) exist, one session has an empty project, and `ccsl-codev/cregit` has `directory=/home/elliancarlos/Projects` (the parent, not the repo). `engram projects consolidate [--all] [--dry-run]` exists to merge similar names.

### Read interfaces
| Path | How | Output | Notes |
|---|---|---|---|
| CLI search | `engram search <q> [--type T] [--project P] [--scope S] [--limit N]` | text: `[n] #id (type) - title`, content truncated | FTS-backed. Prints an "update available" banner first. No `--json` in `--help`. |
| CLI context | `engram context [project]` | text, recent sessions and observations | Empty for a project with no recent session. |
| CLI misc | `stats`, `projects list`, `timeline <obs_id> [--before N --after N]`, `export [file]`, `doctor --json`, `conflicts list/show` | `export` and `doctor` are JSON | `export` is the reliable structured dump of all memories. |
| HTTP API | `engram serve [port]` (default 7437, `ENGRAM_PORT`); optional `ENGRAM_HTTP_TOKEN` bearer auth on delete/export/import routes only | JSON | `--help` mentions routes `/export`, `/import`, `/sessions/{id}`, `/observations/{id}`, `/prompts/{id}`, `/sync/status`, `/projects/migrate`. The read/search routes were not verified (see open points). |
| MCP | `engram mcp [--tools=agent\|admin\|all] [--project NAME]`, stdio; env `ENGRAM_PROJECT` sets the default project | tools `mem_search`, `mem_context`, `mem_get_observation`, `mem_save`, ... | Project defaults to cwd detection unless overridden. Registered for Claude Code in `~/.claude.json` against a nix-store engram binary. A standalone worker gains nothing over the CLI from MCP. |
| Direct SQLite | open `~/.engram/engram.db` with `mode=ro` | rows | Verified with Python `sqlite3` URI `mode=ro`. The `sqlite3` binary is not installed. FTS5 via `observations_fts MATCH`. Couples to the v1.20.0 schema. |
| Obsidian export | `engram obsidian-export --vault P [--project] [--since]` | markdown files | Not needed here. |

### Free-text prompt to project path
- Observed: `engram search cregit` returned top hits from project `msr-2027-data-tool-paper` (a paper about cregit schemas), not the cregit repo. Text search ranks by content mention, so a naive top hit resolves to the wrong project.
- Better index: `SELECT project, directory FROM sessions` gives project to absolute path (for example `.dotfiles` to `/home/elliancarlos/Projects/.dotfiles`, `kirocrew-nix` to `.../KiroCrew-nix`). Match the prompt against project names and observation titles, then map via `sessions.directory`. Rows whose directory is a parent (the cregit case) or whose project is empty need a fallback such as the SQLite project index in the map.
- Treat the result as a hint with a confidence, consistent with the map's "ambiguity logged as an assumption".

## mnemon

### Storage layout
- Data dir `~/.mnemon` (flag `--data-dir`, env `MNEMON_DATA_DIR`); named stores at `data/<store>/mnemon.db` (here only `default`); selected by `--store`, `MNEMON_STORE` or an active-store file; `mnemon store create|list|set|remove`.
- Tables: `insights(id uuid, content, category, importance, tags json, entities json, source, access_count, created_at, updated_at, deleted_at, ...)`, `edges(source_id, target_id, edge_type in temporal|semantic|causal|entity, weight, metadata)`, `oplog`. Soft delete via `deleted_at`.
- Live state: 87 live insights (26 context, 6 decision, 19 fact, 5 insight, 31 preference), 38 soft-deleted, 1330 edges. `~/.mnemon/prompt/{guide,skill}.md` are the prompts injected by the Claude hook.

### Read interfaces
- `mnemon recall [keyword] [--basic] [--cat C] [--intent WHY|WHEN|ENTITY|GENERAL] [--limit N] [--source S]`: graph-enhanced retrieval. Output is JSON: `results[]` with `insight{id, content, category, importance, tags, entities, source, access_count, created_at, updated_at}`, `score`, `intent`, `via`, `signals{keyword, entity, similarity, graph}`, plus `meta`. `--basic` is SQL LIKE.
- `mnemon search [query] [--limit N]`: token-scored keyword search, JSON.
- `mnemon related <id> [--depth N] [--edge temporal|semantic|causal|entity]`: BFS over the graph, for assembling context.
- `mnemon status` (JSON: category counts, top entities, db path), `mnemon log [--limit]`, `mnemon viz`, `mnemon embed` (Ollama embeddings; the `similarity` signal is 0 unless embeddings were generated).
- `--readonly` opens the DB read-only with no WAL files; the intended flag for a worker that must not write.
- `recall` appears to bump `access_count` (a hit showed 95), so a normal recall writes. Use `--readonly` for pure reads.
- mnemon is global, not per-project. Insights mention repos and entities in text (cregit appears as an entity in a my-resume insight), so it supplies user-level and cross-repo context, not an authoritative project-to-path map.
- The per-turn `[mnemon:recall]` injection is a Claude hook; a standalone worker must call `recall` itself with a focused keyword query (the guide says not to pass the raw user prompt).

## Non-interactive worker access (facts, not a decision)
- mnemon: `mnemon recall "<keywords>" --readonly --limit 5`, parse JSON, expand with `mnemon related <id>`.
- engram: read-only SQLite (or `engram export` / `engram serve`) for structure; plain `engram search` for text snippets, filtering the banner lines.
- Both can be read while a Claude session is running (WAL).

## Write-back outside Claude Code
- Source: `~/.claude/agents/memory-scribe.md`. A Claude Code subagent (model haiku; tools Bash, Read, Grep, Glob). It picks the store (mnemon for user/cross-repo facts, engram for the current project), composes the payload, and runs:
  - `mnemon remember "<insight>" --cat <preference|decision|fact|insight|context|general> --imp <1-5> --tags <csv> --source agent` (also `--entities`, `--no-diff`). Dedupe and conflict detection are built in; output includes `action` (added/updated/skipped) and candidate lists (`~/.mnemon/prompt/skill.md`).
  - `engram save "<title>" "<content>" --type <bugfix|architecture|decision|discovery|pattern|learning|manual> --scope <project|personal> [--project <name>] [--topic <topic_key>]`. A save can return conflict candidates that need judging (MCP `mem_judge` or `engram conflicts`).
- There is no standalone `memory-scribe` executable (`which memory-scribe` finds nothing). Two routes outside a session:
  1. Call the two CLIs directly from the worker, with composition done by the worker's own agent run. The CLIs are local and free; only composing text costs tokens.
  2. Invoke the subagent headlessly: `claude -p "<save intent + routing>" --agent memory-scribe`. Flags confirmed in `claude --help`: `-p/--print`, `--agent`, `--agents`, `--output-format`, `--allowedTools`, `--permission-mode`, `--max-budget-usd`, `--no-session-persistence`, `--bare`. `--bare` skips hooks; confirm the `~/.claude/agents` definition still resolves under it.
- engram project name: the scribe falls back to the cwd basename, which in a job worktree is a throwaway name. The worker must pass `--project` explicitly with the canonical name (`.dotfiles` vs `dotfiles` already diverged).
- The Claude Stop-gate that prompts for saves is a hook and does not apply to a headless worker; saving must be an explicit pipeline step.

## Open points
- engram HTTP read/search routes and JSON shapes were not verified (probe was blocked by the sandbox); check upstream source before depending on `serve`.
- Whether `mnemon --readonly` skips the `access_count` update was not checked at DB level.
- Both stores are small (131 and 87 records), so index quality rather than volume limits repo resolution.
