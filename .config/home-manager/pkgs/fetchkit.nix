# everruns/fetchkit -- web fetching + HTML-to-Markdown; `fetchkit mcp` runs an
# MCP server over stdio. Replaces the Python mcp-server-fetch.
{ lib, rustPlatform, fetchFromGitHub, pkg-config, openssl }:
rustPlatform.buildRustPackage rec {
  pname = "fetchkit";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "everruns";
    repo = "fetchkit";
    rev = "v${version}";
    hash = "sha256-5rfuczDx6mDwaPwEymie8JmqFPEXfPDUsTF9XjYXjPU=";
  };

  cargoHash = "sha256-97h7bMWW3n/w+atjLF6vnxD1XJKhHNTAzj7+ZhikR8o=";
  cargoBuildFlags = [ "--package" "fetchkit-cli" ];
  doCheck = false;

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];

  meta = {
    description = "AI-friendly web content fetching and HTML-to-Markdown CLI/MCP server";
    homepage = "https://github.com/everruns/fetchkit";
    license = lib.licenses.mit;
    mainProgram = "fetchkit";
  };
}
