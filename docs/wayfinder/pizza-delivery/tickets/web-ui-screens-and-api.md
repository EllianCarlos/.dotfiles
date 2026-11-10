---
title: Web UI screens and API surface
type: prototype
status: closed
assignee: EllianCarlos
blocked_by: []
---

## Question

What the localhost web UI shows and does: job board, per-job timeline from the ledger, document and decision browser by artifact kind, feedback inbox with reply, status and quota view. Which API endpoints and live-update stream it needs, how TypeScript types are generated from the Rust core API types, and whether Cloudscape is the intended component library. Resolve with a rough clickable or static prototype to react to.

## Resolution

Prototype: three variants on one route (job board plus detail panel, feedback inbox first, ledger with swimlanes), kept on branch `prototype/web-ui-screens-and-api` (throwaway, not merged).

**Verdict: variant A (job board plus detail panel) is the base design.** Cloudscape stays. Two more views are required on top of it, and everything is ported to a TUI.

- **Views over the same jobs.** Table (the prototype's A), Board (columns by job state: queued, running, parked, needs you, done), and Pipeline (one lane per job, one segment per stage, sized by estimate; borrowed from variant C). A segmented control switches between them. The detail panel (stages, feedback, artifacts) is shared by all three.
- **Inbox.** Feedback stays reachable from the top bar badge and the detail panel. Variant B's reply-and-spawn card is the inbox screen. Replies and dismiss are the UI's only writes besides submit and cancel.
- **Event stream.** Variant C's event table survives as the per-job and global ledger view, filterable by event family.
- **API consequence.** The daemon serves read projections that already match these views (jobs by state, per-job stage plan with estimates, feedback list, events since a sequence, quota) plus submit, reply, dismiss, cancel and one live event stream. The web UI and the TUI consume the same projections, so view shapes are defined once in the Rust core types and TypeScript types are generated from them.
- **TUI port.** The TUI is a second client of the same daemon API with the same three views, the inbox and the detail panel. It is in scope.

Assumed, not confirmed by the user (recorded as defaults): no API surface beyond the list above, and the UI is read-mostly.

Surfaced: which TUI library and how the TUI shares view models with the core crate is a separate decision (ticket TUI client and shared view models).
