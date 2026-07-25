{ pkgs, ... }:
let
  lib = pkgs.lib;
  secretsEnvFile = /home/elliancarlos/.secrets/.env;
  mcp-services-nix = import (fetchTarball "https://github.com/natsukium/mcp-servers-nix/archive/main.tar.gz") { inherit pkgs; };

  # uv's managed-Python downloads are generic dynamically-linked binaries
  # that NixOS can't run without nix-ld -- force uv to use nixpkgs' own
  # Python instead of fetching its own. Verified: without this, `uvx`
  # fails with "Could not start dynamically linked executable".
  uvPythonEnv = ''
    export UV_PYTHON=${pkgs.python312}/bin/python3.12
    export UV_PYTHON_PREFERENCE=only-system
  '';

  # mcp-obsidian's shebang is `#!/usr/bin/env node`, unpatched since npx
  # fetches it fresh at runtime instead of nixpkgs building it -- needs
  # node's directory on PATH. Verified: without this, npx fails with
  # "env: 'node': No such file or directory".
  nodePathEnv = "export PATH=${pkgs.nodejs}/bin:$PATH";

  # Generic wrapper: exec `exe args...` after running some setup shell
  # snippets first (env exports, secret loading). Used for every
  # settings.servers entry below so each gets exactly the env it needs
  # without polluting the others.
  mkWrapper =
    {
      name,
      exe,
      args ? [ ],
      extraEnv ? [ ],
      withSecrets ? false,
    }:
    pkgs.writeShellScriptBin name ''
      ${lib.concatStringsSep "\n" extraEnv}
      ${lib.optionalString withSecrets ''
        export $(${lib.getExe' pkgs.coreutils "cat"} ${lib.escapeShellArg secretsEnvFile} | ${lib.getExe pkgs.gnugrep} -v '^#' | ${lib.getExe' pkgs.findutils "xargs"} -d '\n')
      ''}
      exec ${lib.escapeShellArg exe} ${lib.escapeShellArgs args} "$@"
    '';
in
mcp-services-nix.lib.mkConfig pkgs {
  flavor = "claude-code";
  programs = {
    context7.enable = true;
    playwright.enable = true;
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
  settings.servers = {
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
          extraEnv = [ nodePathEnv ];
          exe = "${pkgs.nodejs}/bin/npx";
          args = [ "-y" "mcp-obsidian@1.0.0" "/home/elliancarlos/Projects/mestrado-space/mestrado" ];
        }}/bin/obsidian-mestrado-wrapped";
    };
    obsidian-second-brain = {
      command =
        "${mkWrapper {
          name = "obsidian-second-brain-wrapped";
          extraEnv = [ nodePathEnv ];
          exe = "${pkgs.nodejs}/bin/npx";
          args = [ "-y" "mcp-obsidian@1.0.0" "/home/elliancarlos/Projects/second-brain" ];
        }}/bin/obsidian-second-brain-wrapped";
    };
    # Remote, Cockroach Labs-hosted server -- no local process, no secret.
    # First real use triggers an interactive OAuth login (mcp:read/mcp:write
    # scoped to your Cloud account); Claude Code caches the token itself.
    cockroachdb-cloud = {
      type = "http";
      url = "https://cockroachlabs.cloud/mcp";
    };
  };
}
