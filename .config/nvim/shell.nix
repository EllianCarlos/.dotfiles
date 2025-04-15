{ pkgs ? import <nixpkgs> {} }:

let
  rustOverlay = import (builtins.fetchTarball {
    url = "https://github.com/oxalica/rust-overlay/archive/refs/heads/master.tar.gz";
  });
  pkgsWithRust = import <nixpkgs> { overlays = [ rustOverlay ]; };
in
pkgsWithRust.mkShell {
  nativeBuildInputs = with pkgsWithRust.buildPackages; [
    unzip
    gcc
    nodejs
    gnumake
    rustc
    cargo
    python
  ];

  # Set environment variables for writable Rust directories
  RUSTUP_HOME = "$HOME/.rustup";
  CARGO_HOME = "$HOME/.cargo";

  # Automatically initialize Rust environment
  shellHook = ''
    export PATH="$CARGO_HOME/bin:$PATH"
  '';
}

