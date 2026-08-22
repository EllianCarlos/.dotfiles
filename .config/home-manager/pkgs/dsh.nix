# dsh (https://deepseek.com/harness, github.com/deepseek-ai/deepseek-harness)
# -- DeepSeek's open-source AI coding-agent harness. Not in nixpkgs, and it
# ships no binary releases (its dsh-v0.1.0-rc.* tags are source-only) --
# the only distribution channel is npm, as @deepseek-ai/dsh. It is also in
# fast-moving developer preview (a new rc roughly every two days), so
# vendoring a pinned build here would go stale almost immediately. This
# wraps `bunx` instead, using the `bun` installed in modules/packages.nix,
# so `dsh` always resolves the latest published npm version at run time --
# the same behaviour `npx` would give, without adding a Node.js dependency.
#
# `bunx` treats an already-on-$PATH binary with the same name as the
# requested package's own bin entry as a shortcut: it just execs that
# binary instead of resolving the npm package. The npm package's bin is
# also named `dsh`, and this very script is installed as `dsh` on $PATH --
# so an unguarded `exec bunx ... dsh` recursively re-execs itself forever,
# printing nothing and eventually exiting 1. Confirmed with `strace -f`:
# hundreds of nested execve("dsh") calls, no writes. Confirmed the fix by
# running the real cached entry (`bun ~/.bun/bin/dsh --help`) directly,
# which works -- the npm package itself is fine.
#
# The fix: build $PATH for the bunx child from every directory currently
# on $PATH, minus any entry literally named `dsh` (self or a stale global
# shim), merged into one temp directory so the rest of $PATH survives
# unfiltered. bunx can then no longer find a same-named shortcut and
# correctly resolves the real npm package.
{ pkgs, ... }:
pkgs.writeShellScriptBin "dsh" ''
  set -euo pipefail

  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT

  IFS=':' read -ra dirs <<< "$PATH"
  for d in "''${dirs[@]}"; do
    [ -d "$d" ] || continue
    for f in "$d"/*; do
      [ -e "$f" ] || continue
      name=$(basename "$f")
      [ "$name" = "dsh" ] && continue
      [ -e "$tmpdir/$name" ] || ln -s "$f" "$tmpdir/$name"
    done
  done

  exec env PATH="$tmpdir" ${pkgs.bun}/bin/bunx --bun @deepseek-ai/dsh "$@"
''
