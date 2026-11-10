---
title: Dynamic MCP activation and catalog
type: grilling
status: closed
assignee: EllianCarlos
blocked_by: [mid-run-mcp-activation-in-headless-agents, agent-adapters-and-routing-rules]
---

## Question

How does an agent activate an MCP server for itself and deactivate it after use: where the catalog of allowed MCP servers lives, how a request is expressed and approved without human input, who starts and stops the server process, how credentials and network allowlist extensions are scoped to the stage, the maximum lifetime and cleanup on crash, and what the ledger records.

## Resolution

Decided with the owner (Q1 to Q6 accepted as proposed; Q7 amended).

- **Mechanism**: every agent session gets one always-on broker MCP server provided by the daemon, exposing `mcp_list`, `mcp_activate(name)`, and `mcp_deactivate(name)`. Activated servers' tools appear as namespaced tools where the agent supports `list_changed` (`claude`, Hermes); a generic `mcp_call(server, tool, args)` tool always works as the fallback. No dependence on a CLI-specific mid-run API.
- **Catalog and approval**: a TOML section of the daemon config. Each entry has a name, launch command or URL, credential references, allowed stages and agents, the egress hosts it needs, an idle timeout, and a read-only or write-capable flag. Agents may activate only catalog entries. Approval is policy: auto-approved entries activate immediately; a request for a non-auto or unknown entry is denied and recorded as a feedback entry ("wanted MCP X because Y").
- **Process lifecycle**: the daemon starts the MCP server (stdio) or connects to its URL, scoped to the requesting stage and under the same sandbox profile as the agent. It ends on explicit deactivate, always at stage end, on an idle timeout (default 10 minutes), or at a maximum lifetime; orphan cleanup after a crash uses the pid-lease mechanism. MCP servers the owner already configures globally for agent CLIs (engram, mnemon, and similar) stay as they are and bypass the broker.
- **Credentials and egress**: catalog entries reference credentials by name from a daemon-side secret source (env file or systemd credentials outside any repo), injected only into the MCP server process, never into the agent's context. The egress allowlist is extended for the stage with the entry's declared hosts and retracted on deactivation.
- **Limits**: a cap on simultaneously broker-activated servers per stage (default 3); write-capable entries only in stages their entry allows; stage templates may override the per-stage allowed list.
- **Discovery**: stage prompts carry only a short catalog index (name plus one-line description); `mcp_list` returns the same; a server's full tool schemas load only on activation.
- **Baseline (amended)**: stage templates and triage may pre-declare MCPs that start with the session, as the static fallback for agents without `list_changed` support. This is optional per adapter: not every agent has to support pre-declaration or the broker up front, only the ones that need it. Adapters declare MCP support as capabilities (broker with `list_changed`, pre-declared at launch, none), and routing uses those capabilities like any other. The ledger records every request, activation, denial with reason, deactivation with reason (explicit, stage end, idle, timeout, crash), and per-server tool-call counts.
