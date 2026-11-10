# pizza-delivery design spec

Hand-off spec for implementing `pizza-delivery` in its own repository (`EllianCarlos/pizza-delivery`), imported into the dotfiles repo through a pinned Nix flake. Every section records decisions made in the wayfinder map at `docs/wayfinder/pizza-delivery/`; the tickets there hold the full reasoning. Vocabulary is defined in `GLOSSARY.md`.

## Purpose

`pizza-delivery "<prompt>"` enqueues a job. A local daemon runs parallel workers that triage the job, enrich it from memory (engram and mnemon), route each stage to a local agent CLI by rules and quota, and run self-grill, `to-spec`, `implement-spec`, `code-review`, then open a draft pull request. Agents never ask the human questions. Assumptions, unanswered questions and risks land in a feedback queue. The human replies, and each reply spawns exactly one follow-up job.

### Non-goals

- Multi-machine or distributed queue. The store interface stays swappable, nothing more.
- Remote access by any method other than the Cloudflare Tunnel with Cloudflare Access described below.
- Merging pull requests, sudo, or rebuilds by an agent.

## Architecture

- **Language and style**: Rust, functional style. Pure core: state transitions are `(state, event) -> (state, effects)`; side effects (SQLite, subprocesses, git, transport) sit behind traits at the edges. `unwrap`, `expect` and `panic` are denied through workspace clippy lints. `thiserror` in the core, `anyhow` only in the binary.
- **Process shape**: one daemon schedules work and spawns one child process per running stage. systemd supervises only the daemon, as a socket-activated user unit on `default.target` (never `graphical-session.target`, which does not activate on the owner's host), `Restart=on-failure`. The daemon binds `127.0.0.1` on a fixed port for HTTP and a unix socket for the CLI and TUI.
- **Clients**: the CLI, the TUI and the web UI are all clients of one daemon API. Request, response and view-model types are defined once in the core crate. The CLI-to-daemon transport is a unix socket (codec left to implementation); an HTTP/JSON adapter serves the browser and any other web client. Server-sent events carry the live event stream.
- **Store**: operations only behind a trait (enqueue job, claim stage with lease, append event, read job timeline, list feedback, create follow-up job). First implementation is SQLite in WAL mode. Append-only is enforced in the database with triggers rejecting `UPDATE` and `DELETE` on the events table.

## Ledger, artifacts and handoffs

- **Source of truth**: the append-only events table. Job and stage state derive by folding events through the pure state machine. The `jobs` and `stages` tables are rebuildable projections.
- **Envelope**: ULID id, job id, optional stage id, per-job sequence, timestamp, actor (daemon, agent or human), kind, typed payload. A global monotonic insertion rowid supports live tailing ("events after N").
- **Event families**: job (submitted, triaged, parked, completed, failed, cancelled); stage (planned, claimed, lease-expired, started, handoff-written, succeeded, failed, retried, plan-amended); agent (invoked with agent, model, template name, version and prompt sha256; quota-signal; finished with usage); feedback (assumption-recorded, question-recorded, answered, dismissed); change (commit, branch-pushed, pr-opened, review-finding); memory (context-read, write-back); human (reply-received); MCP (requested, activated, denied, deactivated); sandbox and egress audit fields per invocation.
- **Retention**: events are kept forever. Only artifacts such as transcripts may be compressed or cleaned later.
- **Artifacts**: files in `<data-dir>/jobs/<job-id>/stages/<n>-<stage>/` (grill transcript, spec, review report, handoff, raw agent output, interruption notes, memory write-back list). The ledger indexes each with kind, relative path and sha256. Code changes are referenced by commit hash in the worktree. Specs, designs and decision records belonging to the target repo are committed there. An artifact index by kind powers `show <job> --artifact <kind>` and the web UI document browser.
- **Handoff document**: Markdown with required frontmatter and sections: goal, what was done, decisions made, assumptions, open questions, files touched, instructions for the next stage. Free text inside sections. The core validates it before a stage can succeed; an invalid handoff means retry or fail. The next stage receives it plus the artifact index of earlier stages.
- **Feedback entries**: assumption (text, confidence low, medium or high, alternatives considered, impact); unanswered question (text, why unanswerable, what was assumed instead); risk. `reply` targets one or more entries of one job and always creates exactly one follow-up job whose context is the parent job, the answered entries and the reply text. Answered entries show "answered by <follow-up job>". `dismiss` is a separate event with no follow-up job. A reply never mutates the original job.

## Pipeline

### Stage catalog

| Stage | Skill | Handoff | Success |
|---|---|---|---|
| triage | none (typed result) | triage result | valid typed result |
| investigate | `research`, read-only | report artifact and findings | report has findings and sources |
| grill | `grilling` run as a self-interview | decisions and assumptions | question tree exhausted or round cap hit |
| spec | `to-spec`, then a ticket task graph | spec path and ticket list | spec has required sections; tickets form a valid acyclic graph |
| implement | `implement-spec` (with `tdd` inside) | branch state and test results | tests pass; commits exist on `pizza/<job-id>` |
| review | `code-review` (standards and spec axes) | review report with finding count | report written and findings classified |
| ship | none; daemon-run | PR link | branch pushed and draft PR opened, body rendered from the handoffs |
| memorize | cheap agent, daemon-appended after ship | memory write-back list | write-backs reconciled; never blocks |

### Triage (stage zero)

- Input: raw prompt, optional `--repo`, daemon-assembled `context.md`. Output: one typed result with resolved repo (path, confidence, alternatives), ordered stage plan with a reason per stage, per-stage budget estimate, risk flags and a restated enriched task. Written as a handoff and a ledger event.
- Repo resolution cascade: `--repo`, then a project index (engram `sessions.directory` plus a `~/Projects` scan) matched by name or fuzzy search, then a model judgment over the top candidates. Low confidence takes the best candidate and logs an assumption. No candidate ends the job as `needs-human` with a feedback entry. Index lookup is deterministic Rust; the model only breaks ties.
- Plan templates: full feature (grill, spec, implement, review, ship); bug fix (grill, implement, review, ship); investigate-then-decide (investigate, grill on whether a PR is needed, implement if yes, review, ship). Later stages may amend the plan with ledgered `plan-amended` events, bounded by a maximum stage count (default 10). Report-only jobs end with a report artifact and no ship stage.
- Budget: triage assigns each stage a size tier (small, medium, large). Numbers come from ledger history (median tokens and wall time by stage type, tier and agent) with config defaults at cold start. Actuals are recorded beside estimates. A configurable per-job budget cap (default high) is the only point where the system pauses a job: an estimate above the cap still runs with a high-severity feedback entry; actual usage above the cap parks the job as `needs-human` with a feedback entry.
- `context.md`: size-capped (about 8k tokens), sources listed. Relevant engram observations, a mnemon recall of global preferences, recent ledger history for the repo, and pointers to the repo's own conventions files.

### Stage prompts

- Every stage prompt starts with one fixed autonomy preamble: never ask the human; wherever a skill says to ask, interview or check with the user, take the recommended answer and record an assumption or question feedback entry with a confidence level; it names the stage's inputs and the handoff to write. Skills remain the owner's real skills, referenced by name.
- Templates are Markdown with `{{placeholders}}` filled by the daemon and a `version` in the frontmatter. They are embedded in the binary and overridable from the config directory. The `agent-invoked` event records template name, version and rendered-prompt sha256. Agents without skill support get a pinned copy of the skill text inlined.
- **Self-grill**: the agent writes each round in the skill's format and answers every question itself from `context.md`, memory and the repo, with a confidence level. A low-confidence or unanswerable question becomes an assumption or question feedback entry. It stops when no new questions remain or after a round cap (default 3), and never blocks. The transcript is an artifact; the handoff lists decisions.
- **Spec and tickets**: no external tracker. The spec and its task-graph tickets are local Markdown files committed in the job's worktree (for example `docs/specs/<job-id>/spec.md` and `tickets/`). No `ready-for-agent` label and no seam check with a user; seams are stated in the spec with an assumption entry when unsure.
- **Implement**: one daemon stage running `implement-spec` with the agent's own subagents (an adapter `subagents` capability). The daemon does not schedule individual tickets. An agent without the capability runs tickets sequentially. Routing prefers agents that have it.
- **Review-fix loop**: blocking findings make the daemon plan a fix stage (implement, with the review report as handoff) and a re-review, capped at 2 fix rounds. After the cap, ship proceeds and remaining findings become high-severity risk feedback entries. The loop never blocks on a human.
- **Interruption note**: on timeout, quota exhaustion or crash, the daemon commits uncommitted work to the worktree as a WIP commit and writes an interruption-note artifact (stage, reason, files touched, last known progress, remaining work) from the ledger and the diff, unless the agent wrote one. The retry or fallback agent receives it with the previous handoff.

## Agents, routing and quota

- **Adapter trait** in the core, one subprocess wrapper per CLI. Input: prompt, working directory, MCP config, session to resume, model. Output: a normalized event stream (text, tool use, usage, quota signal, final result with session id). Raw CLI output is kept as an artifact. Each adapter declares capabilities as data: skill expansion, resume, `subagents`, structured quota, MCP support (broker with `list_changed`, pre-declared at launch, or none).
- **Capability-based routing**: each stage declares required capabilities. Skill-driven stages route only to adapters that expand skills (today `claude`); cheap stages (triage, summaries, memorize) can use any adapter.
- **Routing rules**: declarative TOML in the daemon config, evaluated top to bottom. Rules match on stage, budget tier, target repo and required capabilities, and yield an ordered chain of candidates (agent plus model). The router is a pure function: `(stage, quota snapshot, rules) -> ordered candidates`. Defaults ship with the tool; owner config overrides.
- **Quota**: `claude` uses the `rate_limit_event` stream proactively (skip a candidate above a configurable utilization threshold). Hermes, opencode and `agy` are reactive: classify errors by exit code and text into quota-exhausted, with cooldown until a known reset or a default backoff. Every quota signal is a ledger event; the router reads a projection of the latest snapshot.
- **Failure taxonomy**: transient (retry same candidate), quota exhausted (fall back), terminal provider error (fall back; fail if the chain is exhausted), timeout, crash, configuration error such as an unknown skill (fail fast, never retried). Claude's exit code is never trusted alone; the result JSON (`is_error`, `subtype`) is checked too.
- **Fallback and parking**: stage-level. On quota exhaustion the next candidate restarts the stage from its input with an interruption note. If every candidate is exhausted the job is parked as waiting-for-quota until the earliest known reset (or periodic probes if none), then resumes on its own. Same-agent `--resume` after a reset is an allowed optimization.
- **Usage accounting**: every invocation records normalized usage (tokens in and out, cost if reported, wall time, model, candidate position); unknown values stay empty.
- **Known CLI facts** (from research, unverified live): `claude -p --output-format stream-json` with `/skill args` expands skills but passes unknown ones as text, so check `system/init.slash_commands`; Hermes `chat -q -Q --format stream-json`; opencode `run --format json`; `agy -p --output-format json`. Quota-exhaustion shapes and exit codes are unobserved.

## Workers and isolation

- **Leases**: a small mutable operational table (holder, expiry, child process id and start time), heartbeated by the daemon. The ledger records only claimed, lease-expired and released. Rebuildable after a crash.
- **Scheduling**: caps on running stages: global (default 2), per agent (from routing config), per repo (default 2). Stages within a job are sequential. Queue order is priority, then submit time; `--priority` on submit; follow-up jobs default to high priority.
- **Worktrees**: one per job, reused across stages, at `<data-dir>/worktrees/<repo-slug>/<job-id>` on branch `pizza/<job-id>` from the repo's default branch. A follow-up job branches from the parent's tip when the parent made commits. A completed, pushed, clean worktree is removed after a retention period (default 14 days). Failed jobs and any worktree with unpushed or dirty work are never deleted automatically.
- **Git safety**: the daemon serializes git administration per repo (worktree add and remove, fetch, prune) with an in-process lock. The ship step (push `pizza/<job-id>`, open the draft PR) is a deterministic daemon effect; agents only commit locally. Local git and gh credentials are the owner's.
- **Timeouts and retries**: per-stage defaults scaled by budget tier and overridable (starting points: triage 5 min, grill 20, spec 20, implement 60, review 20; job cap 3 hours). A timeout kills the process group (terminate, then kill after a grace period) and gets one retry. Transient failures retry up to two times. Quota fallbacks do not count against retries.
- **Crash recovery**: on daemon start, stages marked running with an expired or missing lease have their orphaned process groups killed and are requeued as a new attempt carrying an interruption note; at the attempt cap the stage fails. Worktrees are kept.
- **Cancel and shutdown**: `cancel <job>` terminates the running stage, marks the job cancelled and keeps the worktree. On shutdown the daemon stops claiming, allows a grace period, and leaves the rest to crash recovery.

## Safety and sandbox

- **Pluggable `Sandbox` trait** in the core (none, bubblewrap, systemd-run scope, container), selectable per profile. Hard requirement: no sandbox may prevent the pipeline from using the tools it needs (git, gh, nix, devenv, cargo, agent CLIs, engram, mnemon, MCP servers, model-API network). Each profile passes a tool-compatibility smoke check before use. No sudo is needed or granted.
- **Permissions**: agents run under the owner's existing agent permission rules. "No merge" is enforced by deny rules plus branch protection on target repos.
- **Egress allowlist** is a sandbox profile property, extended per stage when an MCP server is activated. Blocked requests are ledgered.
- **Diff policy**: changes to CI workflows, git hooks, `.envrc`, devenv or flake files and install scripts push as a labelled draft PR with a high-severity risk feedback entry. Prompt-injection hardening is deprioritized because only the owner can submit jobs.
- **Per-repo trust config** (allowed hosts, protected paths, push remote, resource limits) lives in the daemon's own config, never in the target repo.
- **Audit**: per agent invocation the ledger records sandbox profile hash, mounts, egress allowlist, blocked requests, MCP activations, diff-policy result, pushed ref and PR URL.

## Dynamic MCP

- Every agent session gets an always-on broker MCP server from the daemon with `mcp_list`, `mcp_activate(name)`, `mcp_deactivate(name)` and a generic `mcp_call(server, tool, args)` fallback. Activated tools appear namespaced where the agent supports `list_changed`; `mcp_call` always works.
- **Catalog**: a TOML section of the daemon config with name, launch command or URL, credential references, allowed stages and agents, required egress hosts, idle timeout, and a read-only or write-capable flag. Agents may activate only catalog entries. Auto-approved entries activate immediately; a non-auto or unknown request is denied and recorded as a feedback entry.
- **Lifecycle**: the daemon starts the server (stdio) or connects to its URL, scoped to the requesting stage under the same sandbox profile. It ends on explicit deactivate, at stage end, on idle timeout (default 10 minutes) or a maximum lifetime. Orphan cleanup uses the pid-lease mechanism. MCP servers the owner already configures globally (engram, mnemon and similar) bypass the broker.
- **Credentials** are referenced by name from a daemon-side secret source outside any repo, injected only into the MCP server process, never the agent's context.
- **Limits**: at most 3 broker-activated servers per stage; write-capable entries only in stages their entry allows. Prompts carry only a short catalog index; full tool schemas load on activation.
- **Baseline**: stage templates and triage may pre-declare MCPs that start with the session, the static fallback for agents without `list_changed`. Adapters declare MCP support as capabilities and routing uses them.
- The ledger records every request, activation, denial with reason, deactivation with reason and per-server tool-call counts. Whether claude's streaming SDK or a broker emitting `list_changed` works end to end is unverified and must be tested early.

## Memory

- **Reads**: every stage, triage included, has live read and write access to engram and mnemon through the owner's existing MCP and CLI setup. The daemon refreshes context before each stage with a stage-specific memory query and records the memory ids included as `context-read` events.
- **Write-back**: a final `memorize` stage, appended by the daemon after ship, run by a cheap agent. It calls the engram and mnemon CLIs directly, using the owner's `memory-scribe` when the adapter supports named subagents. It runs for completed, failed and needs-human jobs, not cancelled ones, and never blocks (a failure adds a risk feedback entry).
- **What counts as durable**: save little. engram (project): one summary observation per job, discovered conventions, bug fixes and architecture facts from the handoffs, and a what-failed-and-why note for failed jobs. mnemon (global): only the owner's directives and corrections from replies on follow-up jobs, plus facts spanning repos. Agents never infer owner preferences from their own assumptions; an assumption becomes a memory only after the owner confirms it in a reply. Nothing derivable from the repo or git history.
- **Routing**: a project fact goes to engram, a user or cross-repo fact to mnemon, never both. The engram project name is the canonical one from triage.
- **Duplicates and contradictions**: read-only search first; update an existing memory instead of creating a duplicate. Never silently overwrite a memory pizza-delivery did not write: a contradiction adds a risk feedback entry and skips the write. A conflict with an earlier pizza-delivery memory supersedes it through the store's mechanism.
- **Audit**: reconcile by querying each store for entries tagged with the job id (catching mid-run saves), emit one `write-back` event per entry, and write a `memory-writeback` artifact. No `forget` command; the owner retracts with their own tooling.
- **Facts** (research): engram and mnemon are local SQLite CLIs readable without a session. mnemon `recall` emits JSON and has `--readonly`; engram CLI search is text only (use export, `serve` or read-only SQLite for structured reads); engram `sessions.directory` is the best project-to-path index.

## Surfaces

### CLI

- `pizza-delivery "<prompt>"` submits, prints the short id and exits. Flags: `--repo`, `--priority`, `--file <path>` or `-`, `--follow`, `--dry-run` (triage only).
- Ids: any command accepts a unique ULID prefix (like git) and `@last`; ambiguity lists matches and exits 3.
- `status` (table of active and recent jobs), `status <job>` (stage timeline with attempts, usage, quota state), `status --quota`, `--follow`. `inbox`, `inbox show`, `inbox dismiss`, `reply <job or entries...> "text"` (opens `$EDITOR` prefilled when text is omitted). `show <job> [--artifact <kind>]`, `logs <job> [--stage <n>]`, `open <job> [--pr]`, `cancel <job>`, `install-service`.
- Human tables on a TTY, JSON lines with `--json` or when piped, colors respect `NO_COLOR`. Exit codes: 0 success, 1 general error, 2 usage, 3 not found or ambiguous, 4 daemon unreachable after the socket-activation attempt, 5 job ended unsuccessfully when `--follow` was used. Shell completions are generated and shipped.

### Notifications

A `Notifier` trait; `notify-send` for mako first. Normal urgency: job completed (with PR link) and new high-severity feedback. Critical: job failed or ended `needs-human`. Low: a job parked on quota longer than 15 minutes. Coalesced to at most one per job per state; clicking opens the job's web UI page; each event type can be muted; a failed notification is logged and never fails a job.

### Views and web UI

- **Views** over the same jobs: Table, Board (one column per job state: queued, running, parked, needs you, done) and Pipeline (one lane per job, one segment per stage sized by estimate). A control switches between them. The detail panel (stages, feedback, artifacts) is shared. The inbox is the feedback card list with reply-and-spawn-follow-up and dismiss. The event stream is filterable by event family.
- **Web UI**: TypeScript on Bun with Cloudscape (React); base design is the prototype's job board plus detail panel (branch `prototype/web-ui-screens-and-api` in the dotfiles repo). Writes are limited to submit, reply, dismiss and cancel.
- **API**: read projections that already match the views (jobs by state, per-job stage plan with estimates, feedback list, events since a sequence, quota) plus submit, reply, dismiss, cancel, and one live event stream. View models are pure functions of the ledger projections defined once in the core crate; TypeScript types are generated from them with `ts-rs`, committed under `web/src/generated/`, and CI fails on drift.

### Remote access

Off by default and owner-only. A Cloudflare Tunnel (`cloudflared`) maps a hostname (`pizza.elliancarlos.com.br`, assuming that domain is on Cloudflare) to the daemon's `127.0.0.1` HTTP adapter; Cloudflare Access is the mandatory identity layer. The tunnel is deployed from dotfiles as a NixOS module using `services.cloudflared.tunnels.pizza`, with the credentials file at `/etc/cloudflared/pizza.json` (root 0600, out of git). pizza-delivery never starts `cloudflared`; it reads a `[remote]` config section: `enable`, Access team domain, `aud` tag, allowed emails, allowed origin, `allow_submit`.

- **Enforcement**: a request carrying Cloudflare headers (`Cf-Ray`, `Cf-Connecting-Ip`) must carry a valid `Cf-Access-Jwt-Assertion`, or it gets 401. The daemon checks the signature against the team's cached public keys (refreshed on an unknown key id), `aud`, `iss`, expiry and the email allowlist. A request without Cloudflare headers is a local client, trusted as before.
- **Permissions**: the allowlisted identity may read, reply, dismiss, cancel and submit. Remote submits are rate-limited (default 20 per hour); `remote.allow_submit` can turn them off.
- **Browser safety**: state-changing endpoints require a matching `Origin`, a JSON content type and an `X-Pizza-Client` header; no permissive CORS.
- **Ledger**: a remote-human actor kind carrying the Access email and Cf-Ray id. Rejected authentications become `auth-rejected` events aggregated per time window.
- **Startup guard**: enabling remote access with an empty email allowlist or a missing `aud` tag fails daemon startup. The unix-socket CLI and the TUI are unchanged.
- **PWA**: the daemon serves a manifest, icons and a service worker that caches only the app shell. Offline shows a stale read-only snapshot; there is no offline write queue in version one. At phone width the inbox is the landing page and the three job views stay reachable.
- **Web Push**: VAPID keys are generated on first start (private key in the data directory, mode 0600). Subscriptions live in an operational table, with ledgered subscribe and unsubscribe events. A `WebPushNotifier` implements `Notifier` with the same urgency mapping and coalescing as mako. Payloads carry only job id, state and a short title. Clicking opens the job page on the tunnel hostname. iOS needs the PWA installed (16.4 or later).

### TUI

A `pizza-delivery tui` subcommand of the binary, behind a default-on cargo feature, using ratatui with crossterm. It is a daemon client that deserializes the same view models and applies live events through the same pure reducer from the core; on reconnect it resumes from its last sequence number and takes a snapshot if the gap is gone. Same three views, inbox, detail panel and event stream. Keys: arrows or vim keys; `1`/`2`/`3` switch views, `Tab` focus, `Enter` detail, `/` filter, `?` help, `q` quit; writes `r` reply (opens `$EDITOR`), `d` dismiss, `c` cancel with confirmation, `n` new job; `o` opens the web page, `O` the draft PR. Running `pizza-delivery` with no arguments on a TTY opens it; off a TTY with no arguments it prints usage and exits 2. It honors `NO_COLOR`, requires at least 80x24, uses ASCII fallbacks without a UTF-8 locale, and is tested with ratatui `TestBackend` snapshots over view models.

## Repository, build and packaging

- **Repo**: `EllianCarlos/pizza-delivery`, public, MIT OR Apache-2.0 (add `LICENSE-APACHE`, rename `LICENSE` to `LICENSE-MIT`, set the Cargo `license` field in the first commit).
- **Layout**: `crates/pizza-delivery-core` (pure, publishable), `crates/pizza-delivery` (binary with daemon, CLI and `tui` feature), `web/` (Bun, React, Cloudscape), `prompts/` (stage templates embedded in the binary), `docs/` (this spec, glossary, ADRs), plus `devenv.nix`, `.envrc`, `flake.nix`.
- **Web assets** are embedded in the binary. The crates.io package includes a prebuilt `web/dist` generated at release time, not committed to main. Bun is needed only for development and for the Nix and release builds.
- **Nix**: the flake builds with crane (cached dependencies, web build as a separate derivation embedded in the binary) and exposes `packages.default`, `overlays.default` and `homeManagerModules.default`. The module adds `services.pizza-delivery` with `enable`, `package` and a `settings` attrset rendered to the TOML config, and a socket-activated user unit pair on `default.target`. Dotfiles consumes it through a pinned entry in `pins.nix` with the existing `builtins.getFlake` pattern, so `check-nix-pins` covers bumps, preferring tags.
- **Releases**: a tag `vX.Y.Z` triggers GitHub Actions that publish `pizza-delivery-core` then `pizza-delivery` to crates.io, build cargo-dist binaries for Linux (x86_64, aarch64) and macOS with checksums and an installer script, and update a Homebrew tap. AUR and other managers come later. `install-service` writes the systemd user units for non-Nix Linux users; macOS runs the daemon manually until launchd support exists. SemVer, starting at 0.x.
- **CI**: fmt, `clippy -D warnings`, tests, `nix build`, web typecheck and the type-drift check.
- **Seed contents**: this spec in `docs/designs/`, the glossary, and ADRs only for the hard-to-reverse choices (Rust core plus TypeScript web, ledger as source of truth, one daemon with a child process per stage). The wayfinder map, tickets and research branches stay in the dotfiles repo as history.

## Verify early

These were reported by research subagents or are defaults, not tested:

- Quota-exhaustion shapes and exit codes for each agent CLI. Capture real failing-run fixtures before trusting any classifier.
- Whether a broker MCP emitting `list_changed` and the claude streaming SDK (`setMcpServers`) work end to end; opencode in-flight MCP pickup; `agy` per-turn config reads.
- engram HTTP read routes and mnemon `--readonly` access-count behaviour.
- Timeout, retry, cap and cooldown numbers against real runs.
- Headless `/skill` expansion for `to-spec` and `implement-spec`, which are marked user-invoked only on the owner's machine.

## Decision index

Tickets in `docs/wayfinder/pizza-delivery/tickets/`: headless agent CLIs and quota; memory enrichment access paths; language and daemon architecture; ledger, feedback and handoff schema; sandbox and injection safety; mid-run MCP activation research; agent adapters and routing rules; parallel workers and worktree isolation; triage and budget estimate; dynamic MCP activation and catalog; CLI surface and notifications; web UI screens and API; TUI client and shared view models; stage definitions and prompt templates; memory write-back protocol; repo bootstrap and packaging.
