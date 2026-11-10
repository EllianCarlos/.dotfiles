---
title: CLI surface and notification rules
type: grilling
status: closed
assignee: EllianCarlos
blocked_by: []
---

## Question

The full command set and output of the pizza-delivery CLI (submit, status, inbox, show, reply, cancel, follow) including flags and exit codes, and when and how mako notifications fire (job finished, low-confidence assumption, needs-human, quota parked) with the click-through behaviour.

## Resolution

Decided with the owner (all seven proposals accepted).

- **Submit**: bare `pizza-delivery "<prompt>"` submits a job, prints its short id, and exits immediately. Flags: `--repo`, `--priority`, `--file <path>` or `-` for stdin, `--follow` to tail live, `--dry-run` to run triage only and show repo, stage plan, and estimates without executing.
- **Identifiers**: every command accepts a unique prefix of a job's ULID (like git) and `@last` for the most recently submitted job; an ambiguous prefix lists the matches and exits with the not-found-or-ambiguous code.
- **`status`**: plain `status` shows a table of active and recent jobs (short id, age, repo, state, current stage out of total, agent and model, elapsed against estimate, open feedback count, PR link). `status <job>` shows the stage timeline with attempts, usage, and quota state. `status --quota` shows the per-agent quota snapshot and parked jobs. `--follow` tails the live event stream. Every command accepts `--json`.
- **`inbox` and `reply`**: `inbox` lists open feedback entries grouped by job, ordered by severity (high-severity risks, low-confidence assumptions, unanswered questions); `inbox show <entry>` gives detail. `reply <job or entries...> "text"` creates the follow-up job and opens `$EDITOR` with the entries prefilled when the text is omitted. `inbox dismiss <entry>` acknowledges an entry with no follow-up job (a dismissed event in the ledger).
- **Reading results**: `show <job>` prints the summary (plan, outcome, PR, feedback counts); `show <job> --artifact <kind>` prints an artifact (spec, handoff, report, context); `logs <job> [--stage <n>]` prints raw agent output; `open <job>` opens the job's web UI page, `open <job> --pr` the draft PR.
- **Conventions**: human tables on a TTY, JSON lines with `--json` or when piped, colors respect `NO_COLOR`. Exit codes: 0 success, 1 general error, 2 usage error, 3 job or entry not found or ambiguous, 4 daemon unreachable after the socket-activation attempt, 5 job ended unsuccessfully (failed, cancelled, or needs-human) when `--follow` was used. Shell completions are generated from the command definitions and shipped with the package.
- **Notifications**: a `Notifier` trait with `notify-send` for mako as the first implementation (ntfy or others later). Normal urgency: job completed (with PR link) and new high-severity feedback (a risk or low-confidence assumption). Critical: job failed or ended `needs-human`. Low: a job parked on quota longer than a threshold (default 15 minutes). Coalesced to at most one per job per state; clicking opens the job's web UI page through a short-lived detached helper; each event type can be muted in config; a failed notification is logged and never fails a job.
