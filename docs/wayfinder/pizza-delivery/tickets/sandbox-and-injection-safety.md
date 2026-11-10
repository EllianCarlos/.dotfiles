---
title: Sandbox and prompt-injection safety boundaries
type: grilling
status: closed
assignee: EllianCarlos
blocked_by: []
---

## Question

How are the autonomy limits (no merge, sudo, rebuild, or access outside the job worktree) actually enforced for unattended agents: filesystem/network sandboxing, credentials exposed (gh token scope, push rights), handling of untrusted content pulled into context (repo files, web, memory), and what the ledger records for audit.

## Resolution

Decided with the owner; several earlier proposals were relaxed or reversed.

- **Sandboxing is a pluggable, optional layer**, not a fixed mechanism. `core` defines a `Sandbox` trait; implementations (none, bubblewrap, systemd-run scope, container) are selectable per profile. Hard requirement: no sandbox may prevent the pipeline from using the tools and calls it needs (git, gh, nix/devenv, cargo, agent CLIs, engram, mnemon, MCP servers, network to model APIs). Each profile must pass a tool-compatibility smoke check before use. A sandbox is useful but no sudo is needed or granted.
- **Default permissions**: agents run under the owner's existing agent permission rules, not a custom filesystem view. Isolation uses `git worktree` (accepted); the parallel workers ticket keeps its name.
- **Memory and MCP access**: agents may use engram, mnemon, and any MCP directly; the daemon still pre-enriches the job input. Agents should also be able to activate an MCP server for themselves and deactivate it after use. This lifecycle is a new design question, split into its own tickets (research on headless mid-run activation, then catalog and lifecycle design).
- **Network egress**: an egress allowlist stays in the design as a property of a sandbox profile, extendable per stage when an MCP is activated; blocked requests are recorded in the ledger.
- **Credentials**: local first. Version one uses the owner's existing local git/gh credentials through the existing permission rules; the daemon-performs-all-pushes model is deferred. "No merge" is enforced by deny rules in the agent permission profile plus branch protection on target repos. Authentication for the daemon API and web UI (borrowing something like Cloudflare Access) comes after local-first works and stays outside this map; the spec notes it as an extension point.
- **Diff policy and injection**: the path-based diff policy stays (changes to CI workflows, git hooks, `.envrc`, devenv or flake files, install scripts push as a labelled draft PR with a high-severity risk feedback entry). Prompt-injection hardening is deprioritized because only the owner can submit jobs.
- **Per-repo policy and audit**: per-repo trust settings (allowed hosts, protected paths, push remote, resource limits) live in the daemon's own config, never in the target repo. The ledger records, per agent invocation, the sandbox profile hash, mounts, egress allowlist, blocked requests, MCP activations, diff-policy result, pushed ref, and PR URL.
