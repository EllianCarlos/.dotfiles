# stubbedev/nix-mcp -- Go MCP server for nixpkgs/NixOS/home-manager/flakes
# (tools `nix`, `nix_versions`). Drop-in replacement for the Python mcp-nixos,
# which breaks on nixpkgs python mcp 2.x. Speaks MCP over stdio by default.
{ lib, buildGoModule, fetchFromGitHub }:
buildGoModule rec {
  pname = "nix-mcp";
  version = "0.0.2";

  src = fetchFromGitHub {
    owner = "stubbedev";
    repo = "nix-mcp";
    rev = "v${version}";
    hash = "sha256-mFv6XaVpQ5UKqyIiBJOGbGmqoHA7Gkw42WOzwgsaSC8=";
  };

  vendorHash = "sha256-XYkmkCwkHyGJLPOd49QHSob1BQJSNn2UFfRkBj3BMK0=";
  subPackages = [ "." ];
  ldflags = [ "-s" "-w" "-X github.com/stubbedev/nix-mcp/version.Version=${version}" ];

  # Tests may hit the network.
  doCheck = false;

  meta = {
    description = "Low-footprint MCP server for nixpkgs, NixOS options, flakes and the binary cache";
    homepage = "https://github.com/stubbedev/nix-mcp";
    license = lib.licenses.mit;
    mainProgram = "nix-mcp";
  };
}
