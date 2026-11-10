---
title: Stage definitions and prompt templates
type: grilling
status: closed
assignee: EllianCarlos
blocked_by: []
---

## Question

For each catalog stage (triage, investigate, grill, spec, implement, review, ship): required inputs, required capabilities, the skill it invokes headlessly, the handoff it must produce, and its success criteria. Includes the self-grill protocol (how an agent interrogates itself, records assumptions with confidence, never blocks), the bounded review-fix loop, the interruption note format, and how stage prompts are templated and versioned.

## Resolution

Decided with the owner (all eight proposals accepted).

- **Stage table**: triage (no skill; typed result; success is a valid result). Investigate (`research`, read-only; report artifact and findings; success is a report with findings and sources). Grill (`grilling` run as a self-interview; decisions and assumptions; success is an exhausted question tree or the round cap). Spec (`to-spec` plus a ticket task graph; spec path and ticket list; success is a spec with the required sections and an acyclic ticket graph). Implement (`implement-spec` with `tdd` inside; branch state and test results; success is passing tests and commits on `pizza/<job-id>`). Review (`code-review`, standards and spec axes; review report with finding count; success is a written report with classified findings). Ship (no agent, daemon-run; PR link; success is a pushed branch and an opened draft PR with the body rendered from the handoffs).
- **Autonomy preamble**: every stage prompt starts with one fixed preamble: never ask the human; wherever a skill says to ask, interview or check with the user, take the recommended answer and record an assumption or question feedback entry with a confidence level; it names the stage's inputs and the handoff to write. Skills remain the owner's real skills, referenced by name; the preamble carries the headless overrides.
- **Self-grill protocol**: the grill stage runs `grilling` as an interview of itself. Each round is written in the skill's format and every question is answered from `context.md`, memory and the repo, with a confidence level. A low-confidence or unanswerable question becomes an assumption or question feedback entry. It stops when no new questions remain or after a round cap (default 3), and never blocks. The transcript is an artifact; the handoff lists the decisions.
- **Spec stage and tracker**: no external issue tracker. The spec and its task-graph tickets are local Markdown files committed in the job's worktree (for example `docs/specs/<job-id>/spec.md` and `tickets/`). No `ready-for-agent` label and no seam check with the user; seams are stated in the spec, with an assumption entry when unsure.
- **Implement granularity**: one daemon stage running `implement-spec` with the agent's own subagents, a `subagents` adapter capability. The daemon does not schedule individual tickets. An agent without the capability runs the tickets sequentially in one session. Routing prefers agents that have the capability for this stage.
- **Review-fix loop**: blocking findings make the daemon plan a fix stage (implement, with the review report as handoff) and a re-review, capped at 2 fix rounds by default. After the cap, ship proceeds and the remaining findings become high-severity risk feedback entries. Never blocks on a human.
- **Interruption note**: when a stage is cut off by timeout, quota exhaustion or crash, the daemon commits uncommitted work to the worktree as a WIP commit and writes an interruption-note artifact (stage, reason, files touched, last known progress, remaining work) from the ledger and the diff, unless the agent wrote one itself. The retry or fallback agent receives the note and the previous handoff.
- **Templating and versioning**: stage prompts are Markdown templates with `{{placeholders}}` filled by the daemon and a `version` in the frontmatter, embedded in the binary and overridable from the config directory. The `agent-invoked` ledger event records the template name, version and sha256 of the rendered prompt, so changing a template never rewrites history. A template names its skill; agents without skill support get a pinned copy of the skill text inlined.
- **Consequence for adapters**: adds a `subagents` capability next to the existing declared capabilities in the agent adapter trait.
