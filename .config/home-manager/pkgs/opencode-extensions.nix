# Every third-party opencode plugin this config installs beyond
# opencode-claude (see opencode-claude.nix, kept separate since it predates
# this batch and already has its own working wiring). Not in nixpkgs.
#
# vendor/opencode-extensions/{package.json,package-lock.json} declare 10
# packages:
#   oh-my-opencode                 -- background agents, curated LSP/AST/MCP tools
#   opencode-pty                    -- interactive PTY-managed background processes
#   opencode-websearch               -- web search
#   opencode-plugin-inspector        -- plugin/session inspector
#   opencode-vibeguard                -- redacts/restores secrets around LLM calls
#   opencode-wakatime                 -- WakaTime coding-activity tracking
#   opencode-notification              -- desktop notifications on permission/completion
#   @plannotator/opencode               -- interactive plan review with annotations
#   @nick-vi/opencode-type-inject        -- auto-injects TypeScript types into file reads
#   @tarquinen/opencode-dcp               -- prunes obsolete tool output from context
#
# Two packages the user also asked about are deliberately NOT here:
#   - opencode-mem needs @huggingface/transformers -> onnxruntime-node,
#     whose install script downloads a GPU binary tarball straight from
#     GitHub Releases rather than through npm -- there is nothing in a
#     package-lock.json for a fixed-output derivation to pin, so it fails
#     with no network in the Nix sandbox. Skipped per explicit instruction;
#     revisit by pinning that tarball as its own fetchurl if wanted later.
#   - opencode-goal-mode has no plugin entry file at all (no usable `main`/
#     `exports`) -- it's structured as an installer (`bin`, a `postinstall`
#     script that copies its own agents/ and plugins/ dirs into
#     ~/.config/opencode/). That doesn't fit the file://-plugin pattern the
#     other 10 use; skipped rather than force something unverified.
#
# modules/ai/opencode.nix symlinks the resulting node_modules tree to a
# stable location and adds each package's built entry file to
# opencode.jsonc's `plugin` array via a file:// URL -- verified working
# for opencode-claude (see opencode-claude.nix): this makes claude-code/*
# show up in `opencode models` without touching opencode's own
# node_modules, which is shared with its other runtime deps.
{ pkgs, ... }:
pkgs.buildNpmPackage {
  pname = "opencode-extensions-vendor";
  version = "0";
  src = ./vendor/opencode-extensions;
  npmDepsHash = "sha256-wkJ74U+55PNy+bfEOyhk1U7a7HITStYUN2c6hgIUmX4=";
  npmFlags = [ "--legacy-peer-deps" ];
  dontNpmBuild = true;
  installPhase = ''
    mkdir -p $out
    cp -r node_modules $out/node_modules
  '';
}
