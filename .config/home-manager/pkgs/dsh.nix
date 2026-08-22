# dsh (https://deepseek.com/harness, github.com/deepseek-ai/deepseek-harness)
# -- DeepSeek's open-source AI coding-agent harness. Not in nixpkgs, and it
# ships no binary releases (its dsh-v0.1.0-rc.* tags are source-only) --
# the only distribution channel is npm, as @deepseek-ai/dsh. It is also in
# fast-moving developer preview (a new rc roughly every two days), so
# vendoring a pinned build here would go stale almost immediately. This
# wraps `bunx` instead, using the `bun` installed in modules/packages.nix,
# so `dsh` always resolves the latest published npm version at run time --
# the same behaviour `npx` would give, without adding a Node.js dependency.
{ pkgs, ... }:
pkgs.writeShellScriptBin "dsh" ''
  exec ${pkgs.bun}/bin/bunx --bun @deepseek-ai/dsh "$@"
''
