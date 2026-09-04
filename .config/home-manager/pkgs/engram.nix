# engram -- persistent memory for AI coding agents (Gentleman-Programming/engram).
# Per-project working memory: a single Go binary over SQLite + FTS5, exposed to
# agents via MCP stdio (`engram mcp`). Complements mnemon, which holds global
# cross-project knowledge -- the scope split lives in files/claude/CLAUDE.md.
# Not in nixpkgs; upstream ships a static per-platform release tarball, exactly
# like mnemon, so this mirrors pkgs/mnemon.nix.
{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
  pname = "engram";
  version = "1.20.0";
  src = pkgs.fetchurl {
    url = "https://github.com/Gentleman-Programming/engram/releases/download/v1.20.0/engram_1.20.0_linux_amd64.tar.gz";
    hash = "sha256-fcMAMxjjA77iaaR3IUTzzgHI7HAL/VJKrsdncKzTico=";
  };
  unpackPhase = "tar xzf $src";
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/bin
    install -m755 engram $out/bin/engram
  '';
}
