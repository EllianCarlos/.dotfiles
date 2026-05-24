{ config, pkgs, ... }:

# Temporarily disabled: upstream cursor-flake pins Cursor 3.5.17 with a stale
# hash; the AppImage at the pinned URL was replaced by Cursor without a version
# bump, so nix-build fails with a hash mismatch. Re-enable once upstream updates.
# let
#   cursor-flake = builtins.getFlake "github:omarcresp/cursor-flake";
#   system = "x86_64-linux";
# in
{
  environment.systemPackages = with pkgs; [
    # cursor-flake.packages.${system}.default
  ];
}