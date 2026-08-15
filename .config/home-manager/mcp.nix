{ pkgs, ... }:
let
  lib = pkgs.lib;
  secretsEnvFile = /home/elliancarlos/.secrets/.env;
  pins = import ./pins.nix;
  mcp-services-nix = import (fetchTarball "https://github.com/${pins.mcp-servers-nix.owner}/${pins.mcp-servers-nix.repo}/archive/${pins.mcp-servers-nix.rev}.tar.gz") { inherit pkgs; };

  # uv's managed-Python downloads are generic dynamically-linked binaries
  # that NixOS can't run without nix-ld -- force uv to use nixpkgs' own
  # Python instead of fetching its own. Verified: without this, `uvx`
  # fails with "Could not start dynamically linked executable".
  uvPythonEnv = ''
    export UV_PYTHON=${pkgs.python312}/bin/python3.12
    export UV_PYTHON_PREFERENCE=only-system
  '';

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
    "sequential-thinking".enable = true;
    github = {
      enable = true;
      # Never hardcode the token in env/settings.json -- /nix/store is world-readable.
      # This file is read live off disk at launch, never copied into the store.
      envFile = /home/elliancarlos/.secrets/.env;
    };
    filesystem = {
      enable = true;
      args = [ "/home/elliancarlos/" ];
    };
    nixos.enable = true;
    git.enable = true;
    time.enable = true;
    fetch.enable = true;
  };

  # Hand-defined stdio servers -- also identical shape across clients.
  stdioServers = {
    postgres = {
      command =
        "${mkWrapper {
          name = "postgres-mcp-wrapped";
          extraEnv = [ uvPythonEnv ];
          withSecrets = true;
          exe = "${pkgs.uv}/bin/uvx";
          args = [ "postgres-mcp" "--access-mode=restricted" ];
        }}/bin/postgres-mcp-wrapped";
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
