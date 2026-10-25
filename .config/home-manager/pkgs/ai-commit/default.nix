{
  lib,
  rustPlatform,
  pkg-config,
  libgit2,
  zlib,
}:
rustPlatform.buildRustPackage {
  pname = "ai-commit";
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
  buildInputs = [
    libgit2
    zlib
  ];
  env.LIBGIT2_NO_VENDOR = "1";

  meta = {
    description = "Suggest a commit subject and body with a local Ollama model";
    mainProgram = "ai-commit";
    license = lib.licenses.mit;
  };
}
