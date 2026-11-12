{ config, pkgs, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "root" "elliancarlos" ];
  nix.settings.auto-optimise-store = true;

  # Root disk is small; big builds (hyprland, libguestfs, ...) ran out of
  # space in the default build dir. /mnt/nixdata is a separate ext4 disk.
  nix.settings.build-dir = "/mnt/nixdata/nix-build";
  systemd.tmpfiles.rules = [ "d /mnt/nixdata/nix-build 1775 root nixbld -" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    # 30d kept too many generations on the small root disk (store hit 100G).
    options = "--delete-older-than 14d";
  };

  # Dedupe the whole store periodically (auto-optimise only covers new paths).
  nix.optimise.automatic = true;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.allowBroken = true;
  nixpkgs.config.allowUnfreePredicate = _: true;
}