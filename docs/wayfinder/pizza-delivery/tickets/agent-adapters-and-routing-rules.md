---
title: Agent adapters and routing rules
type: grilling
status: closed
assignee: EllianCarlos
blocked_by: [headless-agent-clis-and-quota]
---

## Question

Given the headless CLI facts, what is the adapter interface each agent implements, what format do routing rules take (by stage, job size, repo, remaining quota), how does the fallback chain walk on quota exhaustion, and how is "waiting for quota" detected and resumed.

## Resolution

Decided with the owner (all seven proposals accepted).

- **Adapter interface**: one `AgentAdapter` trait in `core`, implemented per CLI as a subprocess wrapper. Input: prompt, working directory, MCP config, session to resume, model. Output: a normalized event stream (text, tool use, usage, quota signal, final result with session id). Raw CLI output kept as an artifact. Each adapter declares capabilities as data: skill expansion, resume, mid-run MCP change, structured quota.
- **Capability-based routing**: each stage declares required capabilities. Skill-driven stages (self-grill, `to-spec`, `implement-spec`, `code-review`) route only to adapters that expand skills (today `claude`); cheap stages (triage, summaries, bulk reads) can use any adapter. Injecting skill text for other agents is a later extension.
- **Routing rules**: declarative TOML in the daemon config, evaluated top to bottom; rules match on stage, estimated budget tier, target repo, and required capabilities, and yield an ordered chain of candidates (agent plus model). The router is a pure function in `core`: `(stage, quota snapshot, rules) -> ordered candidates`. Defaults ship with the tool; owner config overrides.
- **Quota awareness**: per-adapter quota source. `claude` uses the `rate_limit_event` stream proactively (skip a candidate above a configurable utilization threshold). Hermes, opencode, and `agy` are reactive: classify errors by exit code and error text into quota-exhausted, with cooldown until a known reset or a default backoff. Every quota signal is a ledger event; the router reads a projection of the latest snapshot. Quota-failure shapes are unverified, so the spec must require capturing real failing-run fixtures before classifiers are trusted.
- **Failure taxonomy**: transient (retry same candidate), quota exhausted (fall back), terminal provider error (fall back; fail the stage if the chain is exhausted), timeout, crash, configuration error (for example an unknown skill; fail fast, never retried). Claude's exit code is never trusted alone; result JSON (`is_error`, `subtype`) is checked too. Retry caps and timeouts come from the parallel workers ticket.
- **Fallback and parking**: fallback is stage-level. On quota exhaustion mid-stage the next candidate restarts the stage from its input; the worktree keeps partial work and the daemon adds an interruption note to the new attempt's input. If every candidate is exhausted, the job is parked as waiting-for-quota until the earliest known reset, or periodic probes if none is known, and resumes on its own. Same-agent `--resume` after a reset is an allowed optimization where supported.
- **Usage accounting**: every invocation records normalized usage in the ledger (tokens in and out, cost if reported, wall time, model, candidate position in the chain), unknown values left empty; feeds triage budget estimates and `status` and web UI.
