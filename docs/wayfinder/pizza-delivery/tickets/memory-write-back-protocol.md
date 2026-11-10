---
title: Memory write-back protocol
type: grilling
status: closed
assignee: EllianCarlos
blocked_by: []
---

## Question

What a finished job should save to engram and mnemon: what counts as durable, how it is routed between per-project and global memory, who writes (agents may use both stores directly), how duplicates and contradictions with existing memories are handled, and how write-backs are recorded in the ledger.

## Resolution

Decided with the owner (all six proposals accepted, with one amendment: memory is available at every stage).

- **Memory at every stage (amendment)**: every stage, triage and review included, has live read and write access to engram and mnemon through the owner's existing MCP and CLI setup, as the sandbox ticket already allows. On top of the job-level `context.md`, the daemon refreshes context before each stage with a stage-specific memory query built from that stage's task and the previous handoff, and records the memory ids it included as `context-read` events. Direct saves from any stage are tagged with the job id and reconciled by the final write-back stage.
- **Who writes and when**: each job gets a final `memorize` stage appended by the daemon after ship, run by a cheap agent through the normal routing rules. It calls the engram and mnemon CLIs directly, using the owner's `memory-scribe` when the adapter supports named subagents. It runs for completed, failed and needs-human jobs, not for jobs the owner cancelled. It never blocks: a failure leaves the job's state and adds a risk feedback entry.
- **What counts as durable**: save little. engram (project): one summary observation per job (ask, outcome, PR, key decisions), discovered conventions, bug fixes and architecture facts from the handoffs, and a short what-failed-and-why note for failed jobs. mnemon (global): only the owner's directives and corrections from replies on follow-up jobs, plus facts spanning repos. Agents never infer owner preferences from their own assumptions; an assumption becomes a memory only after the owner confirms it in a reply. Nothing derivable from the repo or git history and no transient state.
- **Routing**: a project fact goes to engram, a user or cross-repo fact to mnemon, never both. The engram project name is the canonical one from triage's repo resolution.
- **Duplicates and contradictions**: before writing, a read-only search of both stores; update an existing memory (engram topic key, mnemon update) instead of creating a duplicate. Never silently overwrite a memory pizza-delivery did not write; a contradiction with such a memory adds a risk feedback entry and skips the write. A conflict with an earlier pizza-delivery memory supersedes it through the store's own mechanism.
- **Ledger and audit**: the final stage reconciles by querying each store for entries tagged with the job id, which also catches mid-run saves, and emits one `write-back` event per entry (store, id, create, update or skip, content hash). It writes a `memory-writeback` artifact listing them, shown by `show <job> --artifact memory` and in the web and TUI detail panels. No `forget` command; the owner retracts with their own tooling using the listed ids.
- **Budget and follow-ups**: the final stage is small and non-blocking, capped at a small size tier, counted in the job's usage. In a follow-up job the reply text is the confirmation channel for the parent's assumptions; only confirmed ones are saved, tagged with both job ids.
- **Consequence for stage definitions**: the stage catalog gains `memorize` as a daemon-appended final stage after ship. The triage ticket's fixed catalog and the stage table stay otherwise unchanged.
