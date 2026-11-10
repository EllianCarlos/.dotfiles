---
title: TUI client and shared view models
type: grilling
status: closed
assignee: EllianCarlos
blocked_by: []
---

## Question

The TUI is a second client of the daemon API with the same views as the web UI (table, board, pipeline, inbox, detail panel, event stream). Which TUI library (ratatui is the likely fit for the Rust workspace), whether it lives in the single binary or a separate crate, whether view models are defined once in the `core` crate and shared by TUI and generated TypeScript, how live updates reach it, how it relates to the existing CLI commands (`status`, `inbox`, `reply`), and keyboard and layout conventions.

## Resolution

Decided with the owner (all six proposals accepted).

- **Library and placement**: ratatui with crossterm. The TUI is a `pizza-delivery tui` subcommand of the existing binary, with its code in a module behind a cargo feature `tui` (on by default). No separate crate. It is a client of the daemon, like the CLI.
- **Shared view models**: the rows each view shows (job rows, board columns including the job-state-to-column mapping, pipeline lanes and segments, inbox items, event rows) are pure functions of the ledger projections, defined once in `core`. The daemon serves them as read endpoints; the TUI deserializes them and the TypeScript types are generated from the same Rust types. Neither client regroups or recomputes.
- **Live updates**: the TUI subscribes to the daemon event stream over the unix socket and applies each event through the same pure `(state, event) -> state` reducer from `core`. On reconnect it resumes from its last sequence number and takes a fresh snapshot if the gap is gone. No polling.
- **Views, keys, writes**: the same three job views as the web UI (Table, Board, Pipeline) plus inbox, detail panel and event stream. Arrows or vim keys; `1`/`2`/`3` switch views, `Tab` moves focus, `Enter` opens detail, `/` filters, `?` help, `q` quits. Writes match the web UI: `r` reply (opens `$EDITOR` prefilled, as in the CLI), `d` dismiss, `c` cancel with confirmation, `n` new job (opens `$EDITOR`). `o` opens the job's web page, `O` its draft PR.
- **Relation to the CLI**: `status`, `inbox`, `reply` and `--follow` are unchanged. `pizza-delivery` with no arguments on a TTY opens the TUI; with a prompt it submits as before; off a TTY with no arguments it prints usage and exits 2.
- **Terminal behavior and tests**: honors `NO_COLOR`, minimum 80x24 with a "terminal too small" notice below that, ASCII fallbacks when the locale is not UTF-8. Views are tested with ratatui `TestBackend` snapshots over view models.
- **Vocabulary**: View, Table, Board and Pipeline added to the glossary.
