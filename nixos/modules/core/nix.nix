{ config, pkgs, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "root" "elliancarlos" ];
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.allowBroken = true;
  nixpkgs.config.allowUnfreePredicate = _: true;
}