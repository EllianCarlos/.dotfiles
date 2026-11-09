---
ticket: headless-agent-clis-and-quota
researched: 2026-11-09
---

# Headless agent CLIs and quota signals

Versions on this machine: claude 2.1.316, hermes 0.21.5 (2026.9.24), opencode 2.2.1, agy 1.4.8.
Sources: `<cli> --help` output, live probes run on this machine (marked PROBE), Hermes installed source under
`/nix/store/vxcawca4yd26xh6qg8l9rddmihai9fjq-hermes-agent-0.21.5/lib/python3.12/site-packages` (marked SRC), the official Claude Code docs
https://code.claude.com/docs/en/headless (marked DOC), and the local shunt module `.config/home-manager/modules/ai/shunt.nix`.

## Summary matrix

| | claude | hermes | opencode | agy |
|---|---|---|---|---|
| Headless call | `claude -p "<prompt>"` | `hermes chat -q "<p>" -Q` or `hermes -z "<p>"` | `opencode run "<msg>"` | `agy -p "<prompt>"` |
| Structured output | `--output-format json` / `stream-json` (needs `--verbose`) | `--format stream-json` (JSONL) on `chat -q`; `-z` is text only | `--format json` (JSONL events) | `--output-format json` / `stream-json` |
| Skill/slash headless | `/skill-name args` in the prompt text is expanded | `-s/--skills` preload; `/cmd` handled in chat REPL | model-invoked `skill` tool only (no flag seen) | slash/skill expansion in print mode unless `--disable-slash-commands` |
| Resume | `--resume <id>`, `-c`, `--fork-session`, `--session-id <uuid>` | `--resume <id\|title\|latest>`, `-c [name]`, `--create-if-missing`, `--in DIR` | `-s <id>` (creates if missing), `-c`, `--fork` | `--conversation <id>`, `-c` |
| Quota signal | `rate_limit_event` in stream-json with utilization per window | `hermes usage --json`; `failure_reason`; exit codes 75/78 only under Kanban env | no dedicated quota command found; `opencode stats` is local usage only | none verified; shunt greps error text |
| Spend cap | `--max-budget-usd` | `--run-budget SECONDS`, `--max-turns` | none seen | `--print-timeout` |

## claude -p

Invocation (DOC, `--help`): `claude -p "<prompt>"`; prompt may also come on stdin (10MB cap). Useful flags for a worker: `--output-format text|json|stream-json`,
`--json-schema`, `--max-budget-usd`, `--permission-mode`, `--allowedTools`, `--permission-prompts none` (deny anything that would prompt, v2.1.259+),
`--no-session-persistence`, `--bare` (skip hooks/skills/CLAUDE.md/memory; but then auth is API key only, never OAuth/keychain), `--fallback-model`, `-w/--worktree`,
`--add-dir`, `--model`, `--effort`, `--session-id`, `--name`. `-p` skips the workspace trust dialog and still runs project hooks and `.mcp.json` servers unless `--bare`/`--safe-mode`/`--restricted`. With no permission mode set, `-p` starts in Manual mode (v2.1.302+) so unlisted tools needing approval are denied (DOC).

Skills and slash commands (DOC): "User-invoked skills and custom commands work. Include `/skill-name` in the prompt string and Claude Code expands it before running." Terminal-only built-ins such as `/login` are unavailable. Forked skills started via `/name` surface in stream-json with `parent_tool_use_id` prefixed `forked-command-` (v2.1.287+). `--disable-slash-commands` disables all. PROBE: `/nonexistent-skill foo` is not an error; it is passed to the model as text (result still `success`). A router must verify skill existence itself, e.g. via `slash_commands` in the `system/init` event (PROBE: init lists `slash_commands`).

Output (PROBE + DOC): `json` gives one object with keys `type:"result"`, `subtype` (`success`, `error_max_budget_usd`, ...), `is_error`, `result`, `session_id`, `total_cost_usd`, `usage`, `modelUsage`, `num_turns`, `stop_reason`, `terminal_reason`, `api_error_status`, `permission_denials`, `structured_output` (with `--json-schema`). `stream-json` needs `--verbose`; last line is the `result` message; first is `system/init` (model, tools, session_id). `--include-partial-messages` for deltas. `system/api_retry` events carry `error` category (`rate_limit`, `overloaded`, `billing_error`, `authentication_failed`, `model_not_found`, `server_error`, ...) and `error_status` (DOC).

Exit codes: 0 success, non-zero on failure (DOC); SIGTERM gives 143 and no result record (DOC). PROBE: unrecognized model exits 1 with a message on stderr; budget exhaustion produced `subtype:"error_max_budget_usd"`, `is_error:true`, `terminal_reason:"budget_exhausted"` (exit code not captured in my probe because of pipe masking, so branch on JSON, not on the code alone). In-run failures such as missing auth are printed as the result on stdout (DOC), so always parse the result object.

Resume (DOC): `--resume <session_id>` (or path to a transcript `.jsonl`), `--continue` for most recent in cwd; session IDs are found across projects on the machine. `--fork-session` for a copy. Cost reported on resume is the conversation total.

Quota / remaining usage (PROBE): with `--output-format stream-json --verbose`, a `rate_limit_event` appears per turn:
`{"type":"rate_limit_event","rate_limit_info":{"status":"allowed","resetsAt":<epoch>,"rateLimitType":"five_hour","overageStatus":...,"isUsingOverage":false,"unifiedWindows":{"five_hour":{"utilization":0.06,"resetsAt":...,"status":"allowed"},"seven_day":{"utilization":0.13,...}}}}`.
That is the only first-party programmatic remaining-usage signal found for subscription auth; `status` is presumably not `allowed` when a window is exhausted (non-allowed values were not observed live, so unverified) and `resetsAt` gives the park-until time. Not present in plain `json` output. Caveat: the schema of this event is not documented on the headless page; pin and test against upgrades.

## hermes

Invocation (`--help`, SRC): two paths.
- `hermes -z "<prompt>"` (oneshot): prints only the final text; approvals auto-bypassed; tools/memory/AGENTS.md loaded; `--usage-file PATH` writes a JSON usage/cost report even on failure. Exit codes (SRC `hermes_cli/oneshot.py`): 0 ok, 2 failed/partial/not completed, 1 completed with no text, 130 interrupted.
- `hermes chat -q "<p>" -Q [--format stream-json]` or `--query-file PATH|-` (stdin, safe for arbitrary text). `--format stream-json` emits JSONL: `{"type":"system","subtype":"init","model","session_id"}`, `text`, `tool_use`, `tool_result`, then terminal `{"type":"result","session_id","exit_code","text","tokens":{...},"duration_ms","error"}` (SRC `hermes_cli/stream_json.py`; PROBE confirmed init and result shapes). Exit codes (SRC `cli_single_query.py`): 0 ok; 1 failed/partial/never ran; 130 interrupted; and ONLY when env `HERMES_KANBAN_TASK` is set: 75 (EX_TEMPFAIL) for `failure_reason` in {rate_limit, upstream_rate_limit, billing, overloaded, server_error, timeout}, 78 (EX_CONFIG) for {auth, auth_permanent, model_not_found, ssl_cert_verification, upstream_blocked}. Setting `HERMES_KANBAN_TASK` to a dummy value might buy a usable rate-limit exit code; unverified and hacky, since it may change other Kanban behavior.
- PROBE: with no credentials the run exits 1 and the result record has `error:"credentials or agent init failed"`.
- Other worker-relevant flags: `-m`, `--provider`, `--reasoning`, `-t` toolsets, `-s/--skills` (preload skills; unknown skills error if none load, else warn and continue, SRC `oneshot.py`), `--yolo`, `--accept-hooks` (no TTY hooks prompt), `--max-turns`, `--run-budget SECONDS`, `-w/--worktree`, `--ignore-user-config`, `--ignore-rules`, `--safe-mode`, `--source tool`.

Slash commands: `/name` skill invocation is implemented in the interactive `cli.py` (`build_skill_invocation_message`); I did not find it wired into the `-q`/`-z` single-query path. Treat headless skill use as `--skills name` preload plus a prompt that tells it to follow that skill. Unverified live (no credentials in this sandbox).

Resume: `--resume <id|title|latest>` / `-r`; `-c [name]`; `--create-if-missing` ("send to this named thread, making it if needed"); `--in DIR` scopes `latest`; resumed sessions cd to the recorded cwd unless `--no-restore-cwd`. The session id is in the stream-json result and on stderr as `session_id: ...`. `hermes sessions list|export` manages the SQLite store.

Quota: `hermes usage [--provider P] --json` prints account limit windows (Codex 5h/weekly, Anthropic OAuth windows, OpenRouter credits); exit 1 when no credential or fetch fails; PROBE: provider gemini has no usage endpoint. `hermes auth reset <provider>` clears exhaustion on pooled credentials; `hermes fallback` configures fallback providers. Internal classification lives in `agent/error_classifier.py` and `agent/rate_limit_tracker.py` (reads `x-ratelimit-*` headers). Hermes is multi-provider, so quota detection depends on the configured provider; the machine default is `gemini-3.6-flash`, which has no usage endpoint, so detect by `failure_reason`/error text in the result.

## opencode

Invocation (`--help`, PROBE): `opencode run [flags] "<message...>"`; flags `--format default|json`, `--model provider/model#variant`, `--agent`, `-f/--file`, `--title`, `--thinking`, `--auto` (auto-approve permissions not explicitly denied), `-c`, `-s <id>` (continue or create), `--fork`. v2 runs against a background service by default; `--standalone` uses a private server, `--server URL` connects to one (relevant for parallel workers and isolation).
PROBE of `--format json`: JSONL events with `type` of `step_start` and `tool_use` (with `part.tool`, `part.state.status/input/output`), each carrying `sessionID` (`ses_...`). Observed: the agent auto-loaded the `using-superpowers` skill via its `skill` tool, i.e. skills are model-invoked, and no `--command` flag exists on `run` in this version. Failure exit codes were not measured (probe output was truncated by `head`) and are not documented in `--help`.
Resume: `-s <id>` or `-c`; `opencode session list|export|delete`.
Quota: `opencode models` lists models, `opencode stats --json --cost --days N` shows local token/cost history; neither reports provider remaining quota. `opencode auth list` shows credentials. No programmatic quota-remaining API was found in this version; detect exhaustion from error events in the JSON stream or provider error text. This is a gap needing a live failing run to characterize.

## agy (Google Antigravity CLI)

Invocation (`--help`): `agy -p "<prompt>"` (alias `--print`, `--prompt`), `--output-format text|json|stream-json`, `--input-format text|stream-json` (NDJSON per line, one turn each), `--json-schema`, `--model`, `--effort low..max`, `--mode accept-edits|auto|plan`, `--dangerously-skip-permissions`, `--sandbox`, `--print-timeout`, `--add-dir`, `--project`, `--agent`, `--disable-slash-commands` ("Disable slash command and skill expansion in print mode", implying expansion is on by default). Resume: `--conversation <id>`, `-c`. `agy models` lists models.
PROBE limitation: in this sandbox `GEMINI_API_KEY` is empty and `~/.gemini/antigravity-cli/settings.json` has `modelProvider: "gemini"`, so every call exits 1 with `modelProvider is set to "gemini" in settings.json, but the GEMINI_API_KEY environment variable is not set`. JSON output shape and exit codes on quota errors were therefore NOT observed live. The error is plain text even with `--output-format json`.
Quota: the only machinery found is the local `agy-shunt` (`modules/ai/shunt.nix`, installed at `~/.claude/hooks/agy-shunt`): runs `agy -p "$PROMPT" --model "$M"` down a model chain, retries with `--effort low` if output says `requires --effort`, and treats non-zero exit OR output matching `RESOURCE_EXHAUSTED|rate[ _-]?limit|quota|429|overloaded|unavailable` (case-insensitive) as quota failure, moving to the next model; exit 1 when the chain is exhausted. This is heuristic text matching, not a structured signal. agy's own log (`~/.gemini/antigravity-cli/cli.log`) shows a `quota_manager` that is skipped under API-key auth ("skipped (not logged in)"), so no remaining-quota query exists for API-key mode.

## Implications for router/worker adapters

- Only claude (rate_limit_event with utilization and resetsAt) gives a structured, pre-emptive remaining-usage signal. Hermes gives `hermes usage --json` for some providers. opencode and agy need reactive detection.
- Reactive detection should combine: process exit code, parsed final JSON/JSONL record (`is_error`, `subtype`, `failure_reason`, `error`), and a text regex like the shunt's as a last resort. Never rely on exit code alone (hermes `-q` collapses many failures to 1; claude reports some failures only in the result object).
- Resume handles: claude `session_id`, hermes `session_id`, opencode `sessionID`, agy conversation id; capture from the first run's output and store in the ledger.
- Headless skills: claude supports `/skill args` directly; others should be driven by prompt text (hermes `--skills`; opencode via model-invoked skill tool; agy slash expansion). Validate availability up front (claude `system/init.slash_commands`).
- Open items needing a live failing run: claude exit code on an exhausted window and non-`allowed` `status` values; opencode failure exit codes and error event shape; agy JSON/exit behavior under 429; whether hermes `-q` slash expansion works.
