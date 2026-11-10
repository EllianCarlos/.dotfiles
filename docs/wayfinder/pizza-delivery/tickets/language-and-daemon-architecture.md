---
title: Implementation language and daemon architecture
type: grilling
status: closed
assignee: EllianCarlos
blocked_by: []
---

## Question

What language/runtime and process shape should `pizza-delivery` have: single daemon vs CLI plus separate worker and web processes, how workers are spawned and supervised (systemd user units on `default.target`), how the localhost web UI is served, and what the thin SQLite store interface looks like. Consider Nix packaging fit and the owner's language comfort.

## Resolution

Decided with the owner (supersedes the initial TypeScript/Bun and CLI-writes-SQLite proposals).

- **Language**: Rust, functional style. Spec rules: `unwrap`/`expect`/`panic` denied via clippy lints; typed errors (`thiserror`) in the core, `anyhow` only at the binary edge; pure core where state transitions are `(state, event) -> (state, effects)`; side effects (SQLite, agent subprocesses, git, transport) behind traits at the edges.
- **Dev environment**: devenv + direnv in the new repo.
- **Repo shape**: Cargo workspace with a pure, I/O-free `core` library crate (domain types, job/stage state machine, ledger event types, store and agent traits; publishable as a crate) and one `pizza-delivery` binary with subcommands (`daemon`, `submit`, `status`, `inbox`, `reply`).
- **Process shape**: a single daemon that schedules work and spawns one child process per running stage; systemd supervises only the daemon (user unit on `default.target`, `Restart=on-failure`), socket-activated so submit works while the daemon is idle. After a restart it recovers orphaned `running` jobs from expired leases (requeue, or fail at the retry cap). Claim/lease details belong to the parallel workers ticket.
- **CLI**: only a client of the daemon, through one API whose request/response types are defined once in `core`. The transport is not fixed to JSON over HTTP: the primary CLI link is a unix socket (codec left to the spec), plus an HTTP/JSON adapter, required for the browser UI and making web communication easy.
- **Web UI**: TypeScript on Bun, a client of the HTTP API, built on an opinionated component library so it does not look generic; owner suggested "the AWS public one", taken to mean Cloudscape (React-based). This knowingly adds a second language; the spec must generate the TypeScript types from the Rust `core` API types to keep duplication minimal.
- **Local name**: `pizza.localhost` is optional sugar, not a decision. Daemon binds to 127.0.0.1 on a fixed port.
- **Store interface**: operations only (enqueue job, claim stage with lease, append event, read job timeline, list feedback, create follow-up job); the schema belongs to the ledger ticket. Append-only enforced in the database (triggers rejecting UPDATE/DELETE on the events table).
- **Delivery**: flake builds the app reproducibly in the Nix sandbox and ships a home-manager module imported by dotfiles; also publishable as a crate and as release binaries for other package managers. Mechanics deferred to spec assembly.
