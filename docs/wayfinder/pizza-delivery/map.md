---
label: wayfinder:map
title: Pizza Delivery - autonomous prompt queue
---

# Pizza Delivery - autonomous prompt queue

Tracker: local markdown. Tickets live in `tickets/<slug>.md` (frontmatter: `type`, `status`, `assignee`, `blocked_by`). A ticket is on the frontier when `status: open`, no `assignee`, and every `blocked_by` ticket is `closed`. Resolution comments are appended to the ticket under `## Resolution`.

## Destination

A hand-off design spec in `docs/designs/` for `pizza-delivery`, ready to implement in its own `gh`-created repo (Nix-imported into this dotfiles repo). `pizza-delivery "<prompt>"` enqueues a job; parallel workers run self-grill -> `to-spec` -> `implement-spec` -> `code-review` and stop at a draft PR, without ever asking the human.

## Notes

- Planning only: each ticket resolves a decision; no application code is built in this map (prototypes only to settle a decision).
- Settled in charting (see Settled foundations): SQLite queue, own repo, router over existing agent CLIs, unattended autonomy up to a draft PR, assumptions go to a feedback queue, replies spawn follow-up jobs.
- Memory: engram (per-project) and mnemon (global) are read to enrich runs and resolve the target repo; write-back goes through `memory-scribe`.
- Host quirk: `graphical-session.target` never activates here; use `default.target` for user services.
- Consult skills `grilling` and `domain-modeling` for HITL tickets; `research` for AFK research tickets.

## Settled foundations (from charting grill)

- Pipeline: self-grill -> `to-spec` -> `implement-spec` -> `code-review` (max two fix rounds) -> draft PR. A triage step picks the stage subset and estimates budget per job.
- One headless agent session per stage; artifacts handed off as files in the job worktree; jobs resumable per stage.
- Autonomy: worktree, edit, test, commit, push branch, open draft PR, under the owner's existing agent permissions. Never merge or sudo; sandboxing is pluggable and optional (see Sandbox ticket).
- Self-grill never blocks: takes its own recommended answer, tags confidence, logs every assumption to the feedback queue.
- Target repo resolved from `--repo` override, else inferred mainly via memory (SQLite project index as secondary aid); ambiguity logged as an assumption.
- Queue: local SQLite behind a thin store interface. Parallel workers, default per-job timeout/retry caps, quota exhaustion parks a job as waiting-for-quota.
- Ledger: append-only event log; makes documents, specs, designs, decisions, status, and inter-agent handoff docs easy to find.
- Surfaces: `status` / `inbox` / `reply` CLI, mako notifications, web UI that is localhost-only by default (read-mostly, reply is the only write), with optional owner-only remote access through a Cloudflare Tunnel and a PWA.

## Decisions so far

<!-- one line per closed ticket -->

- [Remote access: Cloudflare Tunnel, Access auth and PWA](tickets/remote-access-tunnel-auth-and-pwa.md): owner-only remote access through a Cloudflare Tunnel configured in dotfiles, Access JWT verified by the daemon, header-based local-versus-remote rule, browser safety checks, remote actor in the ledger, installable PWA with Web Push through a `Notifier`, off by default.\n\n- [Repo bootstrap and packaging](tickets/repo-bootstrap-and-packaging.md): public dual-licensed `EllianCarlos/pizza-delivery` workspace with core crate, binary, web and prompts; web UI embedded in the binary; ts-rs generated types with CI drift check; crane flake with home-manager module on `default.target` imported into dotfiles via a `pins.nix` pin; tag-driven crates.io, cargo-dist and Homebrew releases.

- [Memory write-back protocol](tickets/memory-write-back-protocol.md): memory readable and writable at every stage with a per-stage context refresh, a daemon-appended non-blocking `memorize` stage after ship, save-little rules, strict engram/mnemon routing, no silent overwrite of memories pizza-delivery did not write, job-id tagging with ledgered reconciliation.

- [Stage definitions and prompt templates](tickets/stage-definitions-and-prompt-templates.md): per-stage skill, handoff and success table, fixed autonomy preamble, bounded self-grill, local-Markdown spec and tickets, one implement stage with agent-internal subagents, review-fix loop capped at two rounds, daemon-written interruption notes, versioned embedded templates recorded in the ledger.

- [TUI client and shared view models](tickets/tui-client-and-shared-view-models.md): ratatui `tui` subcommand behind a default-on feature, view models defined once in `core` and shared with generated TypeScript, live updates through the shared reducer over the event stream, same views and writes as the web UI, no-argument invocation on a TTY opens it.

- [Web UI screens and API surface](tickets/web-ui-screens-and-api.md): variant A (job board plus detail panel) wins on Cloudscape, with Board and Pipeline views added over the same jobs, inbox and event stream kept, reply/dismiss the only writes, shared read projections for web and TUI; TUI port in scope.

- [CLI surface and notification rules](tickets/cli-surface-and-notifications.md): bare-prompt submit plus status, inbox, reply, show, logs, open, cancel with git-style id prefixes, JSON output and fixed exit codes, notifier trait with mako urgency mapping and click-to-open.

- [Dynamic MCP activation and catalog](tickets/dynamic-mcp-activation-and-catalog.md): daemon-provided broker MCP with activate/deactivate and a generic call fallback, TOML catalog with policy approval (denials become feedback), stage-scoped sandboxed lifecycle, secrets kept out of agent context, MCP support as optional adapter capabilities.

- [Triage stage and budget estimate](tickets/triage-and-budget-estimate.md): triage is stage zero emitting repo, stage plan, history-based per-stage estimates and an enriched task; repo resolved by index cascade, amendable plans over a fixed stage catalog, per-job budget cap as the only pause, daemon-assembled context artifact.

- [Parallel workers and worktree isolation](tickets/parallel-workers-and-worktree-isolation.md): operational lease table with ledgered claims, capped priority scheduler, one worktree per job on `pizza/<job-id>` with daemon-serialized git admin and daemon-run ship step, per-stage timeouts and retries, crash recovery by requeue, cancel and graceful shutdown.

- [Agent adapters and routing rules](tickets/agent-adapters-and-routing-rules.md): one adapter trait with declared capabilities, capability-first routing from TOML rules as a pure function, proactive quota for claude and reactive for the rest, fixed failure taxonomy, stage-level fallback with parking, normalized usage in the ledger.

- [Mid-run MCP activation in headless agents](tickets/mid-run-mcp-activation-in-headless-agents.md): only claude (SDK streaming) and Hermes (between turns) plausibly change MCPs mid-run; per-stage generated config with a fresh or resumed session is the baseline, a broker MCP is an unverified option.

- [Sandbox and prompt-injection safety boundaries](tickets/sandbox-and-injection-safety.md): pluggable optional sandbox trait that must never block needed tools, owner's existing permissions plus git worktree, agents use memory and MCPs directly, local-first credentials, path-based diff policy, per-repo trust config in daemon config, audited ledger fields.

- [Ledger, feedback, and handoff-document schema](tickets/ledger-feedback-handoff-schema.md): event-sourced append-only ledger with ULID envelope and rebuildable projections, per-job artifact directories indexed by kind and hash, validated Markdown handoffs, three feedback kinds with replies creating follow-up jobs; vocabulary in the glossary.

- [Implementation language and daemon architecture](tickets/language-and-daemon-architecture.md): Rust workspace (pure `core` crate + one binary), single socket-activated daemon with child process per stage, CLI is a client of the daemon API, web UI is TypeScript/Bun on Cloudscape over an HTTP adapter with types generated from Rust.

- [Headless agent CLIs and quota signals](tickets/headless-agent-clis-and-quota.md): all four CLIs run headless with JSON/JSONL output and resumable sessions; only `claude` exposes structured quota (`rate_limit_event`), the rest need error-text detection; quota-failure exit codes still unverified.
- [Memory enrichment access paths](tickets/memory-enrichment-access-paths.md): both memory stores are readable via local CLI/SQLite without a session; engram `sessions.directory` is the best repo-resolution index; write-back is a direct CLI call or `claude -p --agent memory-scribe`.

## Not yet specified


## Out of scope

- Multi-machine / distributed queue (store interface is kept swappable, nothing more).
- Merging PRs, sudo, `nixos-rebuild` by the agent.
