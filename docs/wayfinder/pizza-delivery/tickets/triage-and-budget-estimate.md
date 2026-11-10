---
title: Triage stage and budget estimate
type: grilling
status: closed
assignee: EllianCarlos
blocked_by: [agent-adapters-and-routing-rules, ledger-feedback-handoff-schema, memory-enrichment-access-paths]
---

## Question

What does triage consume and emit: stage plan, per-stage budget estimate (tokens/time/agent tier), target-repo resolution via memory, and the schema recorded in the ledger. How are estimates used for parallel scheduling and quota-aware routing, and how are they checked against actuals.

## Resolution

Decided with the owner (all seven proposals accepted).

- **Contract**: triage is stage zero of every job and uses the normal handoff mechanism. Input: raw prompt, optional `--repo` override, daemon-assembled context. Output: one typed result with the resolved repo (path, confidence, alternatives), an ordered stage plan with a reason per stage, a per-stage budget estimate, risk flags, and a restated, enriched task for later stages; written as a handoff document and a ledger event.
- **Repo resolution**: cascade of `--repo` flag, then a project index (engram `sessions.directory` plus a `~/Projects` scan) matched by name or fuzzy search, then a model judgment over top candidates using memory for ambiguity. Low confidence takes the best candidate and logs an assumption feedback entry. No candidate at all ends the job in a `needs-human` state with a feedback entry and no further stages. Index lookup is deterministic Rust; the model only breaks ties.
- **Stage catalog and plans**: fixed catalog (investigate, grill, spec, implement, review, ship). Templates: full feature (grill, spec, implement, review, ship); bug fix (grill, implement, review, ship); investigate-then-decide (investigate, grill on whether a PR is needed, implement if yes, review, ship). Later stages may amend the plan through ledgered plan-amended events, bounded by a maximum stage count (default 10). Report-only jobs end with a report artifact and no ship stage.
- **Budget estimate**: triage classifies each stage into a descriptive size tier (small, medium, large); the numbers come from ledger history (median tokens and wall time by stage type, tier, and agent), with config defaults at cold start. Estimates drive timeout scaling, the budget tier in routing rules, and the `status` display; actuals are recorded next to estimates so estimates calibrate over time.
- **Division of labour**: deterministic parts (repo index lookup, history statistics, template defaults) run in Rust; the model does classification, the enriched task restatement, and tie-breaking, routed to a cheap model through the normal routing rules with no special capabilities.
- **Budget caps**: a configurable per-job budget cap (default high). A triage estimate above the cap still runs with a high-severity feedback entry; actual usage above the cap at runtime parks the job as `needs-human` with a feedback entry. This is the only point where the system pauses a job for the owner, and it never blocks on a question.
- **Context assembly**: before triage the daemon assembles a size-capped (default around 8k tokens) `context.md` artifact with its sources listed: relevant engram observations for the project, a mnemon recall of global preferences, recent ledger history for the repo (earlier jobs and PRs), and pointers to the repo's own conventions files. Later stages may re-query memory directly.
