# Packages that are not in nixpkgs, vendored here.
#
# Import from any module that needs one:
#   let custom = import ../../pkgs { inherit pkgs; };
#   in  ... custom.mnemon ...
#
# `loop-tools` is a LIST of derivations. Everything else is a single
# derivation.
{ pkgs }:
{
  wb-headset = pkgs.callPackage ./wb-headset.nix { };
  mnemon = pkgs.callPackage ./mnemon.nix { };
  engram = pkgs.callPackage ./engram.nix { };
  rag-mcp = pkgs.callPackage ./rag-mcp.nix { };
  dsh = pkgs.callPackage ./dsh.nix { };
  pi-extensions = pkgs.callPackage ./pi-extensions.nix { };
  opencode-claude = pkgs.callPackage ./opencode-claude.nix { };
  opencode-extensions = pkgs.callPackage ./opencode-extensions.nix { };

  loop-tools = import ./loop-tools.nix { inherit pkgs; };
}
