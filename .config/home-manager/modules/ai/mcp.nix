{ pkgs, ... }:
let
  lib = pkgs.lib;
  secretsEnvFile = /home/elliancarlos/.secrets/.env;
  pins = import ../../pins.nix;
  custom = import ../../pkgs { inherit pkgs; };
  mcp-services-nix = import (fetchTarball "https://github.com/${pins.mcp-servers-nix.owner}/${pins.mcp-servers-nix.repo}/archive/${pins.mcp-servers-nix.rev}.tar.gz") { inherit pkgs; };

  # Claude Code spawns MCP servers with a stripped env, not a login shell's
  # PATH -- so "$PATH" here can be empty, and npx also shells out to `sh`
  # internally. Without /usr/bin:/bin explicitly present, that spawn fails
  # with "npm error enoent spawn sh ENOENT" (verified by replicating Claude
  # Code's env -i launch locally). Prepending is not enough; /usr/bin:/bin
  # must be included outright.
  nodePathEnv = "export PATH=${pkgs.nodejs}/bin:/usr/bin:/bin:$PATH";

  # Generic wrapper: exec `exe args...` after running some setup shell
  # snippets first (env exports, secret loading). Used for every
  # settings.servers entry below so each gets exactly the env it needs
  # without polluting the others.
  mkWrapper =
    { name
    , exe
    , args ? [ ]
    , extraEnv ? [ ]
    , withSecrets ? false
    ,
    }:
    pkgs.writeShellScriptBin name ''
      ${lib.concatStringsSep "\n" extraEnv}
      ${lib.optionalString withSecrets ''
        export $(${lib.getExe' pkgs.coreutils "cat"} ${lib.escapeShellArg secretsEnvFile} | ${lib.getExe pkgs.gnugrep} -v '^#' | ${lib.getExe' pkgs.findutils "xargs"} -d '\n')
      ''}
      exec ${lib.escapeShellArg exe} ${lib.escapeShellArgs args} "$@"
    '';

  # Shared registry-backed servers -- identical shape (command/args/env) for
  # every client, since these are all local stdio processes. Reused verbatim
  # for both Claude Code and Gemini CLI.
  sharedPrograms = {
    context7.enable = true;
    # --extension attaches to the user's real Chrome/Edge via the
    # Playwright MCP browser extension, instead of launching a separate
    # headless Chromium. Requires the extension to be installed.
    playwright = {
      enable = true;
      args = [ "--extension" ];
    };
    github = {
      enable = true;
      # Never hardcode the token in env/settings.json -- /nix/store is world-readable.
      # This file is read live off disk at launch, never copied into the store.
      envFile = /home/elliancarlos/.secrets/.env;
    };
    nixos.enable = true;
    git.enable = true;
    time.enable = true;
    fetch.enable = true;
  };

  # Hand-defined stdio servers -- also identical shape across clients.
  stdioServers = {
    # filesystem/sequential-thinking -- run via npx against the published,
    # pre-built npm packages instead of `programs.filesystem` /
    # `programs.sequential-thinking` (mcp-servers-nix's own nix-built
    # packages): those compile from source through generic-ts.nix, whose
    # `npmWorkspace = "src/<name>"` doesn't pull in the reference-servers
    # monorepo's root @types/node devDependency that each workspace's
    # tsconfig relies on for ambient `process` types -- build fails with
    # "Cannot find name 'process'" at tsc. Broken at every mcp-servers-nix
    # commit through the pinned reference-servers version (2026.7.10,
    # unchanged upstream since Jul 25). The npm packages ship compiled
    # dist/, so there's no tsc step to hit the bug. Revert to
    # `programs.<name>.enable` once upstream fixes generic-ts.nix's
    # workspace devDependency handling.
    filesystem = {
      command =
        "${mkWrapper {
          name = "filesystem-mcp-wrapped";
          extraEnv = [ nodePathEnv ];
          exe = "${pkgs.nodejs}/bin/npx";
          args = [ "-y" "@modelcontextprotocol/server-filesystem" "/home/elliancarlos/" ];
        }}/bin/filesystem-mcp-wrapped";
    };
    "sequential-thinking" = {
      command =
        "${mkWrapper {
          name = "sequential-thinking-mcp-wrapped";
          extraEnv = [ nodePathEnv ];
          exe = "${pkgs.nodejs}/bin/npx";
          args = [ "-y" "@modelcontextprotocol/server-sequential-thinking" ];
        }}/bin/sequential-thinking-mcp-wrapped";
    };
    # agent-rag-mcp -- local hybrid RAG over ~/rag/corpus (ChromaDB + Ollama
    # qwen3-embedding). The rag-mcp launcher (pkgs/rag-mcp.nix) cds into ~/rag
    # so the server finds its config.yaml, then execs `uvx agent-rag-mcp`.
    # Same launcher is reused for Pi and OpenCode so all three share one index.
    rag = {
      command = "${custom.rag-mcp}/bin/rag-mcp";
    };
    # engram -- per-project working memory (SQLite + FTS5) over MCP stdio.
    # Complements mnemon (global CLI knowledge, cross-project); engram is
    # scoped to the current repo via cwd/.engram/config.json detection.
    # `--tools=agent` exposes the curated agent-facing tool set (mem_save,
    # mem_search, mem_context, mem_session_summary, ...). Absolute store path
    # so it resolves regardless of the stripped env Claude Code launches with.
    engram = {
      command = "${custom.engram}/bin/engram";
      args = [ "mcp" "--tools=agent" ];
    };
    obsidian-mestrado = {
      command =
        "${mkWrapper {
          name = "obsidian-mestrado-wrapped";
          extraEnv = [ nodePathEnv "export SEEKSTONE_VAULT=${lib.escapeShellArg "/home/elliancarlos/Projects/mestrado-space/mestrado"}" ];
          exe = "${pkgs.nodejs}/bin/npx";
          args = [ "-y" "seekstone" ];
        }}/bin/obsidian-mestrado-wrapped";
    };
    obsidian-second-brain = {
      command =
        "${mkWrapper {
          name = "obsidian-second-brain-wrapped";
          extraEnv = [ nodePathEnv "export SEEKSTONE_VAULT=${lib.escapeShellArg "/home/elliancarlos/Projects/second-brain"}" ];
          exe = "${pkgs.nodejs}/bin/npx";
          args = [ "-y" "seekstone" ];
        }}/bin/obsidian-second-brain-wrapped";
    };
    super-productivity = {
      command =
        "${mkWrapper {
          name = "supper-productivity-wrapped";
          extraEnv = [ nodePathEnv ];
          exe = "${pkgs.nodejs}/bin/npx";
          args = [ "-y" "super-productivity-mcp" ];
        }}/bin/supper-productivity-wrapped";
    };
    exa = {
      command =
        "${mkWrapper {
          name = "exa-mcp-wrapped";
          extraEnv = [ nodePathEnv ];
          # Needs EXA_API_KEY from dashboard.exa.ai/api-keys in the secrets
          # file; withSecrets exports the whole file rather than just this
          # one key, matching the postgres/github servers above.
          withSecrets = true;
          exe = "${pkgs.nodejs}/bin/npx";
          args = [ "-y" "exa-mcp-server" ];
        }}/bin/exa-mcp-wrapped";
    };
  };

  # Remote HTTP servers -- shape differs per client. Claude Code wants
  # `type = "http"; url = ...`. Antigravity CLI wants `serverUrl = ...`
  # instead, with no `type` field (https://antigravity.google/docs/cli/mcp/).
  httpServerUrls = {
    cockroachdb-cloud = "https://cockroachlabs.cloud/mcp";
    # OAuth-based: connecting triggers a consent screen to authorize
    # read/write/send access, no static token needed here.
    # https://www.fastmail.com/blog/an-mcp-server-for-fastmail/
    fastmail = "https://api.fastmail.com/mcp";
  };
  httpServersFor = flavor:
    lib.mapAttrs
      (_: url:
        if flavor == "antigravity"
        then { serverUrl = url; }
        else { type = "http"; inherit url; })
      httpServerUrls;

  mkClientConfig = flavor: extraSettings:
    mcp-services-nix.lib.mkConfig pkgs {
      # mcp-servers-nix has no "antigravity" flavor, but "claude-code"
      # already emits the same bare `{ mcpServers = {...} }` shape
      # Antigravity CLI's mcp_config.json expects, so it's reused for both
      # -- only the HTTP server shapes above actually differ per client.
      flavor = "claude-code";
      programs = sharedPrograms;
      settings.servers = stdioServers // (httpServersFor flavor) // extraSettings;
    };
in
{
  claude = mkClientConfig "claude" { };
  antigravity = mkClientConfig "antigravity" { };
}
