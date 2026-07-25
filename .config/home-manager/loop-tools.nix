# CLI tools from cobusgreyling/loop-engineering's tools/ directory, each
# individually published to npm under @cobusgreyling/*. Versions are pinned
# to what was verified working via `npx -y @cobusgreyling/<name>@<version>
# --help` at the time this was written, not left on @latest -- an unpinned
# tag could silently pick up a broken release the way
# @cobusgreyling/loop-mcp-server@1.1.0 already is (see below).
#
# Deliberately excluded:
#   - loop-mcp-server@1.1.0: broken standalone. Its published package.json
#     still lists "@cobusgreyling/loop-gate": "file:../loop-gate", an
#     unresolved relative dependency, so `npx @cobusgreyling/loop-mcp-server`
#     throws ERR_MODULE_NOT_FOUND. Upstream packaging bug, not fixable here
#     (same class of issue as the mcp-obsidian@1.0.0 fix earlier).
#   - loop-sandbox: present in the repo's tools/ dir but never published to
#     npm at all.
#   - readiness-core: internal library dependency for the others, no `bin`,
#     nothing to expose as a CLI.
{ pkgs }:
let
  nodePathEnv = "export PATH=${pkgs.nodejs}/bin:/usr/bin:/bin:$PATH";
  mkNpxTool = { name, version }:
    pkgs.writeShellScriptBin name ''
      ${nodePathEnv}
      exec ${pkgs.nodejs}/bin/npx -y "@cobusgreyling/${name}@${version}" "$@"
    '';
in
[
  (mkNpxTool { name = "loop"; version = "0.1.2"; })
  (mkNpxTool { name = "loop-audit"; version = "1.7.0"; })
  (mkNpxTool { name = "loop-init"; version = "1.5.0"; })
  (mkNpxTool { name = "loop-cost"; version = "1.2.0"; })
  (mkNpxTool { name = "loop-sync"; version = "1.0.0"; })
  (mkNpxTool { name = "loop-context"; version = "1.5.0"; })
  (mkNpxTool { name = "loop-gate"; version = "1.0.0"; })
  (mkNpxTool { name = "loop-worktree"; version = "1.2.0"; })
  (mkNpxTool { name = "goal-audit"; version = "1.0.2"; })
  (mkNpxTool { name = "goal-init"; version = "1.0.0"; })
]
