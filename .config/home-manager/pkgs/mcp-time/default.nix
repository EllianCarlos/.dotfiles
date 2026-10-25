{ lib, rustPlatform }:

rustPlatform.buildRustPackage {
  pname = "mcp-time";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./Cargo.toml
      ./Cargo.lock
      ./src
    ];
  };

  cargoLock.lockFile = ./Cargo.lock;

  meta = {
    description = "MCP server for current time and timezone conversion (Rust replacement for mcp-server-time)";
    mainProgram = "mcp-time";
    platforms = lib.platforms.unix;
  };
}
