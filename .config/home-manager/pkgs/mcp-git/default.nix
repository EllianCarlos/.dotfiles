{
  lib,
  rustPlatform,
  pkg-config,
  libgit2,
}:

rustPlatform.buildRustPackage {
  pname = "mcp-git";
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

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ libgit2 ];

  # Link the system libgit2 instead of building the vendored copy.
  env.LIBGIT2_NO_VENDOR = "1";

  meta = {
    description = "MCP server for git repositories via libgit2 (Rust replacement for mcp-server-git)";
    mainProgram = "mcp-git";
    platforms = lib.platforms.unix;
  };
}
