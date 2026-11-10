---
title: Headless agent CLIs and quota signals
type: research
status: closed
assignee:
blocked_by: []
---

## Question

For each local agent CLI available here (`claude -p`, Hermes, opencode, and `agy`/Gemini for cheap reads): how is it invoked non-interactively, how are skills/slash commands invoked headlessly, what output format and exit codes does it give, how are sessions resumed, and how can quota/rate-limit exhaustion and remaining usage be detected programmatically? Capture the facts a router and worker adapter would depend on, with sources.

## Resolution

Findings on branch `research/headless-agent-clis-and-quota` (commit 1bac376, file `docs/wayfinder/pizza-delivery/research/headless-agent-clis-and-quota.md`; throwaway, never merged). Subagent-reported, not independently verified.

- claude: `claude -p --output-format json|stream-json`; `/skill args` in the prompt expands, but an unknown skill is passed as plain text, so the router must check `system/init.slash_commands`. Resume with `--resume <session_id>` or `-c`. Failures can appear only in the result JSON (`is_error`, `subtype`, `terminal_reason`), not the exit code.
- claude quota: stream-json with `--verbose` emits `rate_limit_event` with `unifiedWindows.five_hour` / `seven_day` (`utilization`, `status`, `resetsAt`). The only structured remaining-usage signal of the four; undocumented. Non-`allowed` statuses and exhausted-window exit code unobserved.
- hermes: `hermes chat -q ... -Q --format stream-json` (final `result` record with `session_id`, `exit_code`) or `-z`. Skills via `--skills`, no `/skill` on the single-query path. Resume `--resume <id|title|latest>`. Exit 75 (rate limit) / 78 (provider error) only when `HERMES_KANBAN_TASK` is set. `hermes usage --json` lacks gemini.
- opencode: `opencode run --format json` (JSONL, `sessionID`); resume `-s`, `-c`, `--fork`. Skills only via the model's own tool. No remaining-quota query; failure exit codes unmeasured.
- agy: `agy -p --output-format json|stream-json`; resume `--conversation <id>` / `-c`. Quota handling is only the local `agy-shunt` regex over error text. Not probed live (empty `GEMINI_API_KEY` in sandbox).
- Open: needs a live failing run per CLI to settle quota-exhaustion shapes and exit codes.
