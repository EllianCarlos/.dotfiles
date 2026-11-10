---
title: Parallel workers and worktree isolation
type: grilling
status: closed
assignee: EllianCarlos
blocked_by: [language-and-daemon-architecture, agent-adapters-and-routing-rules]
---

## Question

How are multiple workers scheduled and kept from colliding: job claiming and leases in SQLite, concurrency limits per agent and per repo, git worktree creation/cleanup, resume after crash, and timeout/retry behaviour per stage.

## Resolution

Decided with the owner (all seven proposals accepted).

- **Leases**: a small mutable operational table (holder, expiry, child process id and start time), heartbeated by the daemon. The ledger records only claimed, lease-expired, and released, not heartbeats. Rebuildable after a crash.
- **Concurrency and priority**: scheduler caps are a global cap on running stages (default 2), a per-agent cap from the routing config, and a per-repo cap (default 2). Stages within a job are sequential. Queue order is priority, then submit time, with `--priority` on submit; follow-up jobs from human replies default to high priority. All caps configurable.
- **Worktree lifecycle**: one worktree per job, reused across stages, at `<data-dir>/worktrees/<repo-slug>/<job-id>` on branch `pizza/<job-id>` based on the target repo's default branch. A follow-up job branches from the parent job's branch tip when the parent made commits. After completion with the branch pushed and the worktree clean, the worktree is removed after a retention period (default 14 days). Failed jobs and any worktree with unpushed or dirty work are never deleted automatically.
- **Shared `.git` safety**: the daemon serializes git administration per repo (worktree add and remove, fetch, prune) with an in-process lock; commits and edits inside a worktree need no lock. The final ship step (push `pizza/<job-id>`, open the draft PR) is a deterministic daemon effect; agents only commit locally. This refines the credentials decision for reliability and still uses the owner's local git credentials.
- **Timeouts and retries**: per-stage-type default wall-clock timeouts, scaled by the triage budget tier and overridable (starting points: triage 5 min, grill 20, spec 20, implement 60, review 20; job-level cap 3 hours). A timeout kills the whole process group (terminate, then kill after a grace period), counts as a timeout failure, and gets one retry before the stage fails. Transient failures retry up to two times. Quota-driven candidate fallbacks do not count against the retry cap. Numbers are defaults for the spec to confirm against real runs.
- **Crash recovery**: on daemon start, stages marked running with an expired or missing lease have their orphaned process groups killed (pid and start time from the lease) and are requeued as a new attempt carrying the same interruption note used for quota fallback; if the attempt cap is hit the stage fails. Worktrees are kept as they were.
- **Cancel and shutdown**: `pizza-delivery cancel <job>` terminates the running stage, marks the job cancelled in the ledger, and keeps its worktree. On shutdown the daemon stops claiming, gives running stages a grace period, then leaves the rest to crash recovery on the next start.
