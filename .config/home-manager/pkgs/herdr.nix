# herdr (https://herdr.dev) -- agent orchestration runtime that
# github.com/AltanS/collie (a phone UI for the agent herd) plugs into.
# Not in nixpkgs; upstream ships a single static binary per release
# rather than a tarball, so this mirrors the mnemon derivation minus the
# unpack step. Collie itself is installed at runtime via
# `herdr plugin install AltanS/collie`, not packaged here.
{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
  pname = "herdr";
  version = "0.8.0";
  src = pkgs.fetchurl {
    url = "https://github.com/herdrdev/herdr/releases/download/v0.8.0/herdr-linux-x86_64";
    hash = "sha256-uHLqfkD6LLF+hXrJtisb8m23tAPGIvXS8/WzX26azSg=";
  };
  dontUnpack = true;
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/bin
    install -m755 $src $out/bin/herdr
  '';
}
