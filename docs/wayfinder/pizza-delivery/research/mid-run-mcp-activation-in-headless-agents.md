# Mid-run MCP activation in headless agents

Ticket: `tickets/mid-run-mcp-activation-in-headless-agents.md`. Checked 2026-11-09 against claude 2.1.316, hermes 0.21.5, opencode 2.2.1, agy (version not reported). Sources: local `--help`, Hermes source in its Nix store path, official docs fetched via web. Throwaway branch, not independently re-verified.

## Short answer

| CLI | Add/remove MCP mid-run, headless? | Mechanism | Verdict |
|---|---|---|---|
| claude | Yes, only through the Agent SDK control channel (streaming input); not through plain `claude -p "prompt"` | `setMcpServers()`, `toggleMcpServer()`, `reconnectMcpServer()`, `mcpServerStatus()` | Workable with a long-lived streaming session |
| hermes | Partially: config-driven reload between turns in a multi-turn session; effectively no for single-query `-z`/`-q` | `/reload-mcp`, config watcher, between-turns refresh | Only between turns, and it invalidates the prompt cache |
| opencode | Yes, via its HTTP server API, if a run is attached to a server | `POST /mcp` "Add MCP server dynamically" | Documented; connect/disconnect endpoints not documented; live behavior unverified |
| agy | Unknown / no evidence | `agy mcp add/remove/enable/disable` edit configuration | Treat as launch-time only |

Generic fallback that works everywhere: generate a per-stage MCP config in the daemon before launching the stage (every stage is already its own headless session per map.md), and use `--resume` across stage boundaries if a tool set must change.

## claude (2.1.316)

- Launch-time flags (local `claude --help`): `--mcp-config <configs...>` (JSON files or strings), `--strict-mcp-config` ("Only use MCP servers from --mcp-config, ignoring all other MCP configurations"), `--tools`, `--allowedTools`/`--disallowedTools`, `--input-format stream-json` (only with `--print`; "realtime streaming input"), `--replay-user-messages`. `claude mcp add|add-json|remove|list|get|login|logout|serve|reset-project-choices` manage persisted config. Source: `claude --help`, `claude mcp --help`.
- Persisted toggles: `/mcp` panel enable/disable stored per project in `~/.claude.json` (`disabledMcpServers` / `enabledMcpServers`). `/mcp` is a TUI panel; `-p` has no panel. Source: https://code.claude.com/docs/en/mcp
- Agent SDK runtime control (TypeScript `Query` interface): `reconnectMcpServer(name)`, `toggleMcpServer(name, enabled)` ("Disabling a server disconnects it and removes its tools"), `setMcpServers(servers)` ("Replace the MCP servers this method manages: servers added through it and in-process SDK servers", returns `McpSetServersResult` listing added, removed, errors), `mcpServerStatus()`. Python has `get_mcp_status()` and `reconnect_mcp_server()`. Source: https://code.claude.com/docs/en/agent-sdk/typescript , https://code.claude.com/docs/en/agent-sdk/mcp
- Version limits: removing tools of a stdio/SSE/HTTP server added mid-session needs Claude Code 2.1.285+; in-process SDK servers 2.1.286+; `reconnectMcpServer` name resolution 2.1.257+. Installed 2.1.316 satisfies these. Same source.
- Not confirmed from the fetched text: whether these methods require streaming input mode (sibling methods like `setModel()` do), and what `setMcpServers` leaves connected from settings files (the `McpSetServersResult` section was truncated). Needs a live test. The SDK drives the CLI over `--input-format stream-json`; that the CLI itself accepts these as control messages is inference, not read from a spec.
- `list_changed`: "In non-interactive mode with the `-p` flag and in the Agent SDK, Claude Code refreshes only the tool list on these notifications." So a server-side change in its tool list reaches a running `-p` session. Source: https://code.claude.com/docs/en/mcp
- Late-connecting servers: with tool search on (default), "when a server finishes connecting while Claude is working, Claude Code lists the server's tool names to Claude on its next request in the same turn." Tool search defers tool schemas; `alwaysLoad: true` exempts a server. Env knobs: `ENABLE_TOOL_SEARCH`, `CLAUDE_CODE_MCP_STARTUP_WAIT_MS` (2.1.274+, `0` skips the wait), `MCP_CONNECTION_NONBLOCKING`, `MCP_TIMEOUT` (30 s default). Source: https://code.claude.com/docs/en/agent-sdk/mcp
- Headless limits: no OAuth flow in `-p` ("complete the sign-in from an interactive session first": `claude mcp login <name>`); project-scoped `.mcp.json` servers load without approval in `-p`; stdio server that exits: "The run continues without the server's tools. To have Claude Code try the connection again, start the run again"; remote servers get 5 reconnect attempts, then background retries up to about half an hour for transient errors. `--strict-mcp-config` plus per-stage `--mcp-config` isolates a stage. In `stream-json` runs, skipped `--mcp-config` entries are reported in `system/init` `mcp_server_errors`. Source: https://code.claude.com/docs/en/mcp
- Tool-list change cost: not documented in the fetched pages as a cache hit; changing the tool array generally invalidates the prompt prefix (stated explicitly only for Hermes, below).

## hermes (0.21.5)

Source for everything below: installed code at `/nix/store/vxcawca4yd26xh6qg8l9rddmihai9fjq-hermes-agent-0.21.5/lib/python3.12/site-packages` (`hermes_cli/config_defaults.py`, `hermes_cli/commands.py`, `tools/mcp_tool_agent.py`, `agent/turn_context.py`, `tools/mcp_tool_health.py`, `hermes_cli/mcp_config.py`).

- Config: `mcp_servers:` in `config.yaml`; CLI `hermes mcp add|remove|list|test|configure|login|catalog|install|serve`. `hermes mcp configure` toggles tool selection. `--ignore-user-config` (and `--safe-mode`) skips user MCP servers; `-t/--toolsets` limits toolsets.
- Runtime reload: slash command `/reload-mcp` ("Reload MCP servers from config", `commands.py:260`); `mcp.auto_reload_on_config_change: true` makes the CLI config watcher reconnect when `mcp_servers` changes. Both are in interactive CLI/gateway/TUI surfaces. The comment states "Every reload rebuilds the tool surface and INVALIDATES the provider prompt cache"; `mcp_reload_confirm: true` asks before reloading. `discovery_concurrency: 4` caps parallel server spawns.
- Between-turns refresh: `_refresh_mcp_tools_between_turns` (`turn_context.py:511`, called at line 1024) re-derives the tool snapshot at the start of each turn via `refresh_agent_mcp_tools(..., preserve_prefix=True)`; existing tools keep their slot, new tools append at the tail, to protect the cached prefix. This is how late-connecting servers appear in multi-turn sessions (gateway, ACP). Mid-turn, the snapshot is frozen.
- `list_changed`: `ToolListChangedNotification` from a server triggers a refresh of that server's tools (`mcp_tool_health.py:100-112`).
- Single query mode (`-z`, `chat -q`): config comment says "With only ONE turn there is no between-turns refresh, so a server that misses the window is invisible for the whole session"; discovery waits up to `mcp_single_query_discovery_timeout: 15.0` s. So in the router's headless path, config must be correct before launch; no mid-run activation.
- ACP (`hermes acp`, `acp_adapter/server.py`) registers client-supplied MCP servers per session and refreshes the tool surface (pre-first-turn only for late discovery). Worth noting as the one Hermes surface with programmatic per-session MCP injection; not tested.

## opencode (2.2.1)

- Local help: `opencode mcp list|add|auth|logout`; `opencode run --format json --session/-s --continue/-c --fork --agent --auto`; `--server <url>` and `--standalone` choose between the background service and a private server; `opencode api <operation | METHOD path>` makes raw requests to the running server; `opencode service start|restart|status|stop|get`. `opencode mcp list` here reports no servers configured. Source: `opencode --help`, `opencode run --help`.
- Docs (https://opencode.ai/docs/mcp-servers/): servers "connect automatically"; `disabled` (not `enabled`) keeps a configured server unconnected; "Use `/mcps` in OpenCode to view, connect, disconnect, or authenticate servers. Disconnecting a server in `/mcps` does not change configuration." Permission actions "hide or deny tools without disconnecting their server." No mention of config reload or `list_changed`.
- Server API (https://docs.opencode.ai/docs/server/): `GET /mcp` "Get MCP server status"; `POST /mcp` "Add MCP server dynamically" body `{ name, config }`; `PATCH /config` "Update config". No connect/disconnect endpoints listed there. Combined with `opencode run --server <url>` / `opencode api`, a daemon could POST a server into a running service. Caveats: the docs pages may describe an earlier major than local v2.2.1 (the docs host redirected between two domains), and I did not run `opencode api` because it would start/touch the background service. Whether a running `run` session picks up the new tools before its next model request is unverified.

## agy

- Local: `agy mcp add|remove|list|enable|disable`; `add` takes `--env`, `--header`, `--type stdio|http`. `agy mcp list` here shows many configured servers (stdio and http) with status. Print mode: `-p`, `--output-format text|json|stream-json`, `--input-format stream-json` (one NDJSON message per turn on stdin), `--conversation <id>`/`-c`, `--agent`, `--disable-slash-commands`.
- The binary embeds the Go MCP SDK (strings show `ToolListChangedParams`), which only shows protocol support exists, not that agy refreshes its tool list. No doc or flag found for per-run MCP config or runtime MCP changes. Verdict: no evidence of mid-run activation; assume config is read at launch (or per turn in stream-json input mode: untested). Not probed live.

## Alternatives, with facts

1. Per-stage generated config (recommended baseline). Daemon writes the MCP set per stage and launches fresh: claude `--mcp-config <file> --strict-mcp-config`; hermes a per-stage `HERMES_HOME`/profile or `--ignore-user-config` plus controlled config (profile mechanics not verified here); opencode per-run config (not verified); agy `agy mcp enable/disable` mutates global config, so races across parallel workers are a risk (not a per-run flag as far as `--help` shows).
2. Restart with resume. All four resume sessions (see headless-agent-clis-and-quota ticket). A new launch with a different MCP set picks up the new tools; history is replayed so the prompt-cache prefix is lost on the changed tool array. Claude: a stdio server that dies stays dead until the run restarts (docs quote above).
3. Long-lived claude streaming session with `setMcpServers`/`toggleMcpServer`. Only claude documents a first-class API. Adds complexity: the daemon must hold the child's stdin and speak the control protocol or embed the Agent SDK instead of calling `claude -p` one-shot.
4. Broker MCP proxying other servers. Not provided by any of the four. The relevant primitive is `list_changed`: claude (`-p`/SDK) and Hermes both honor `tools/list_changed` and refresh the tool list, so one static broker server that adds/removes tools and emits the notification gives mid-run changes without restarting the client. Cost: broker must proxy calls, auth and schemas; not verified end to end. opencode and agy handling of `list_changed` unverified.
5. Deferred tool loading. Claude's tool search (default on) loads only needed tool schemas and lets late-connecting servers appear in the same turn; `alwaysLoad` opts out. This reduces context cost of declaring many servers up front, an alternative to dynamic add for claude. Hermes has a lean toolset mode and `preserve_prefix` append-only refresh; opencode permissions hide tools without disconnecting.

## Open items needing a live test

- Claude: do `setMcpServers`/`toggleMcpServer` work on a `--input-format stream-json` child directly, and which settings-file servers survive `setMcpServers`?
- Claude: does a `list_changed` from a broker add a tool visible to the model in the same turn under `-p`?
- opencode: `POST /mcp` then does an in-flight `run` see the tools; v2.2.1 operation IDs via `opencode api`.
- agy: whether MCP config is re-read per turn in stream-json input mode.
- Hermes: per-stage config isolation via profile/`HERMES_HOME`.
