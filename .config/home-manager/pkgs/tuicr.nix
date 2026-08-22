# tuicr (https://tuicr.dev) -- terminal UI for code review, with vim
# keybindings. Not in nixpkgs; upstream ships a per-platform release
# tarball, so this mirrors the mnemon derivation. Unlike mnemon,
# this binary is dynamically linked against glibc/libz/libgcc_s/libm
# (verified with `patchelf --print-needed`) rather than static, so it
# needs autoPatchelfHook -- without it, NixOS fails with "Could not
# start dynamically linked executable" because /lib64/ld-linux-*.so.2
# doesn't exist outside an FHS environment.
{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
  pname = "tuicr";
  version = "0.21.0";
  src = pkgs.fetchurl {
    url = "https://github.com/agavra/tuicr/releases/download/v0.21.0/tuicr-0.21.0-x86_64-unknown-linux-gnu.tar.gz";
    hash = "sha256-THdLmB0vc9/2dfUJpGzgfvaro+oSfhZnCqqAE0afaAs=";
  };
  nativeBuildInputs = [ pkgs.autoPatchelfHook ];
  buildInputs = [
    pkgs.stdenv.cc.cc.lib
    pkgs.zlib
  ];
  unpackPhase = "tar xzf $src";
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/bin
    install -m755 tuicr $out/bin/tuicr
  '';
}
