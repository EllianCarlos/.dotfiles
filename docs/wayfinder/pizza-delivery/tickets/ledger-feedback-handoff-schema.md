---
title: Ledger, feedback, and handoff-document schema
type: grilling
status: closed
assignee: EllianCarlos
blocked_by: []
---

## Question

What is the append-only event model and storage layout: event types, job/stage state machine, how feedback entries (assumptions with confidence, unanswered questions) and follow-up jobs link back, and where artifacts live (spec, grill transcript, review report, inter-stage handoff docs) so documents, designs, decisions, and status are easy to find from the CLI and web UI.

## Resolution

Decided with the owner.

- **Source of truth**: the append-only events table. Job and stage state are derived by folding events through the pure state machine; `jobs` and `stages` tables are rebuildable projections. Leases are events (stage claimed with an expiry).
- **Event envelope**: ULID id, job id, optional stage id, per-job sequence, timestamp, actor (daemon, agent, or human), kind, typed payload. Payload fields are left to the spec.
- **Event families**: job (submitted, triaged, parked, completed, failed, cancelled); stage (planned, claimed, lease-expired, started, handoff-written, succeeded, failed, retried); agent (invoked with agent and model, quota-signal, finished with usage); feedback (assumption-recorded, question-recorded, answered, dismissed); change (commit, branch-pushed, pr-opened, review-finding); memory (context-read, write-back); human (reply-received).
- **Artifacts**: files in a per-job directory (`<data-dir>/jobs/<job-id>/stages/<n>-<stage>/`) holding grill transcript, spec, review report, handoff, and raw agent output. The ledger indexes each with kind, relative path, and sha256. Code changes are referenced by commit hash in the worktree; specs, designs, and decision records belonging to the target repo are committed there and referenced by commit and path. Transcripts stay out of SQLite. An artifact index by kind powers `show <job> --artifact <kind>` and the web UI document browser.
- **Handoff document**: Markdown with required frontmatter and sections (goal, what was done, decisions made, assumptions, open questions, files touched, instructions for the next stage), free text inside sections. Written by the finishing stage and validated by `core` before the stage can succeed; an invalid handoff means retry or fail. The next stage receives it plus the artifact index of earlier stages.
- **Feedback entries**: three kinds. Assumption (text, confidence low/medium/high, alternatives considered, impact); unanswered question (text, why unanswerable, what was assumed instead); risk. `reply` targets one or more entries of one job and always creates exactly one follow-up job whose context is the parent job, the answered entries, and the reply text. Answered entries show "answered by <follow-up job>"; unanswered ones stay open. A reply never mutates the original job.
- **Identity and ordering**: ULIDs for jobs and events; per-job sequence for ordering within a job; global monotonic insertion rowid for live tailing (`status --follow`, web server-sent events resume from "events after N").
- **Retention**: events kept forever by default; only artifacts such as transcripts are eligible for compression or cleanup later.
- **Vocabulary**: Job, Stage, Handoff, Feedback entry, Follow-up job, Ledger (draft in `GLOSSARY.md` beside the map; moves into the repo once it exists).
