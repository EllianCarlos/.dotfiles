# omniroute (https://github.com/diegosouzapw/OmniRoute) -- an open-source
# AI gateway/router that unifies 350+ AI providers behind one OpenAI-
# compatible endpoint, with CLI, server, and desktop modes. Not in
# nixpkgs, and not a good fit to vendor as a proper derivation: it's a
# pnpm-workspace/Next.js monorepo with native deps (sharp, better-sqlite3,
# keytar, onnxruntime-node) and a custom postinstall build step, and it's
# still fast-moving (v3.8.x, thousands of commits, frequent releases) --
# a pinned buildNpmPackage would be fragile and go stale quickly. Same
# situation as `dsh` (see dsh.nix): npm is the only realistic
# distribution channel, so this uses `bunx` to fetch/cache the latest
# published `omniroute` npm version at run time.
#
# The npm package's own bin is also named `omniroute`, same as this
# script -- so an unguarded `exec bunx ... omniroute` would recursively
# re-exec itself via bunx's already-on-$PATH shortcut (see dsh.nix for
# the confirmed failure mode). Reuses the same fix: build $PATH for the
# bunx child from every directory currently on $PATH, minus any entry
# literally named `omniroute`, so bunx can't find the same-named
# shortcut and resolves the real npm package instead.
#
# Upstream is dual-runtime: its own CLI (bin/cli/commands/serve.mjs)
# spawns the actual Next.js server via `node` when running under Node,
# or via `bun --preload <APP_DIR>/open-sse/utils/setupPolyfill.ts` when
# running under Bun (`process.versions.bun ? ... : "node"`). `bunx`
# always evaluates a package's JS bin *in-process* rather than exec'ing
# it as an OS-level file, so a `#!/usr/bin/env node` shebang is inert --
# `bunx omniroute` runs under Bun regardless of the `--bun` flag, and so
# does everything it then spawns. That matters because `omniroute serve`
# under Bun crash-loops every request with a 500: Next's turbopack
# production server for the app-router dashboard fails to load under
# Bun's CommonJS interop ("Expected CommonJS module to have a function
# wrapper ... this is a bug in Bun" -- confirmed against omniroute 3.8.50,
# reproduces with plain `bunx --bun omniroute serve`, and is a Bun engine
# bug per its own error text, not something fixable via Next config).
# Running the identical cached install under real Node.js hits neither
# problem: no `--preload` flag (so the missing-file packaging bug in
# that flag's target, `dist/open-sse/utils/setupPolyfill.ts`, never
# comes up either), and no turbopack/Bun interop crash -- confirmed
# `node bin/omniroute.mjs serve --daemon` against the same cached
# install serves 307/401 instead of 500 on `/` and `/v1/models`.
#
# So this wrapper uses `bunx` only to populate/refresh bunx's cache with
# the latest release (`--version` is fast-pathed upstream, so this is
# cheap even when already warm), then execs the cached package's own
# entry point directly with `pkgs.nodejs` -- already pulled into the
# store for loop-tools.nix's npx wrapper, so this adds no new closure.
# bunx caches the resolved install per-spec at a deterministic path
# (`/tmp/bunx-<uid>-omniroute@latest`) and reuses it across runs without
# wiping unrelated files, so relying on that path after the fetch step
# is stable.
{ pkgs, ... }:
pkgs.writeShellScriptBin "omniroute" ''
  set -euo pipefail

  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT

  IFS=':' read -ra dirs <<< "$PATH"
  for d in "''${dirs[@]}"; do
    [ -d "$d" ] || continue
    for f in "$d"/*; do
      [ -e "$f" ] || continue
      name=$(basename "$f")
      [ "$name" = "omniroute" ] && continue
      [ -e "$tmpdir/$name" ] || ln -s "$f" "$tmpdir/$name"
    done
  done

  env PATH="$tmpdir" ${pkgs.bun}/bin/bunx --bun omniroute --version >/dev/null 2>&1 || true

  # `serve --daemon` re-spawns the actual server by bare `"node"` (not
  # process.execPath), so the daemon child needs it resolvable on $PATH too.
  pkgdir="''${TMPDIR:-/tmp}/bunx-$(id -u)-omniroute@latest/node_modules/omniroute"
  exec env PATH="${pkgs.nodejs}/bin:$PATH" ${pkgs.nodejs}/bin/node "$pkgdir/bin/omniroute.mjs" "$@"
''
