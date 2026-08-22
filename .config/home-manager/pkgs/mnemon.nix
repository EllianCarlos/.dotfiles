# mnemon -- persistent memory CLI for LLM agents. Not in nixpkgs; upstream
# ships a static per-platform release tarball.
{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
  pname = "mnemon";
  version = "0.1.3";
  src = pkgs.fetchurl {
    url = "https://github.com/mnemon-dev/mnemon/releases/download/v0.1.3/mnemon_0.1.3_linux_amd64.tar.gz";
    hash = "sha256-38pH9YNNSv0yycdufodqvJ+8ofrI5QFm9qm6NnPOQbA=";
  };
  unpackPhase = "tar xzf $src";
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/bin
    install -m755 mnemon $out/bin/mnemon
  '';
}
