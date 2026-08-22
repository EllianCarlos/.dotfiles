# Packages that are not in nixpkgs, vendored here.
#
# Import from any module that needs one:
#   let custom = import ../../pkgs { inherit pkgs; };
#   in  ... custom.herdr ...
#
# `loop-tools` is a LIST of derivations. Everything else is a single
# derivation.
{ pkgs }:
{
  antigravity-cli = pkgs.callPackage ./antigravity-cli.nix { };
  wb-headset = pkgs.callPackage ./wb-headset.nix { };
  mnemon = pkgs.callPackage ./mnemon.nix { };
  tuicr = pkgs.callPackage ./tuicr.nix { };
  herdr = pkgs.callPackage ./herdr.nix { };
  dsh = pkgs.callPackage ./dsh.nix { };

  loop-tools = import ./loop-tools.nix { inherit pkgs; };
}
