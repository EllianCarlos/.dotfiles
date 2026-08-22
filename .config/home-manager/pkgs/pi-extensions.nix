# Every third-party `pi` (pi-coding-agent) extension this config installs,
# vendored in one npm project so shared transitive deps de-duplicate the
# same way a real `pi install npm:<pkg>` run after run would resolve them.
# Not in nixpkgs.
#
# vendor/pi-extensions/{package.json,package-lock.json} declare all 14
# packages as plain dependencies:
#   pi-claude-bridge      -- run Claude models via the real `claude` CLI
#   pi-subagents           -- single-agent delegation / scripted multi-agent
#   pi-mcp-adapter          -- MCP protocol adapter
#   pi-web-access           -- web search, URL fetch, GitHub clone, PDF/video
#   context-mode            -- context-window-saving MCP plugin
#   pi-background-tasks     -- durable background shell tasks
#   @companion-ai/feynman   -- research-first agent (Pi + alphaXiv)
#   @plannotator/pi-extension -- interactive plan review with annotations
#   @dietrichgebert/ponytail -- skips unnecessary work ("lazy senior dev")
#   pi-lens                 -- real-time LSP/lint/type-check feedback
#   @ff-labs/pi-fff          -- fuzzy file/content search
#   pi-goal-x                -- durable long-running objectives
#   @narumitw/pi-plan-mode   -- read-only /plan collaboration mode
#   @mjasnikovs/pi-task      -- deterministic task planning/spec-orchestration
#   pi-vim                   -- vim modal editing in pi's prompt
#
# pi-claude-bridge (and several others) list @earendil-works/pi-ai,
# pi-coding-agent, pi-tui, typebox as peerDependencies -- pi provides these
# itself at runtime. `npm ci` would otherwise try a registry check against
# them even though nothing gets installed (no sandboxed network to satisfy
# it); --legacy-peer-deps skips that check. See pi's own packaging docs:
# https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/packages.md
#
# modules/ai/pi.nix symlinks the resulting node_modules tree to a stable
# location and registers each node_modules/<pkg> subdirectory as a local-path
# package in ~/.pi/agent/settings.json -- pi loads local-path packages
# directly from that directory without copying them into ~/.pi/agent/npm/,
# so this never touches (or risks clobbering) any package the user installs
# by hand with `pi install`.
{ pkgs, ... }:
pkgs.buildNpmPackage {
  pname = "pi-extensions-vendor";
  version = "0";
  src = ./vendor/pi-extensions;
  npmDepsHash = "sha256-ODyntVkjqZeLWq0zWFgmUgh0U/WPnIf1hNY9UWPtcQ0=";
  npmFlags = [ "--legacy-peer-deps" ];
  dontNpmBuild = true;
  installPhase = ''
    mkdir -p $out
    cp -r node_modules $out/node_modules
  '';
}
