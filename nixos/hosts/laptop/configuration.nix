{ config, pkgs, lib, ... }:

{
  imports = [ 
    <home-manager/nixos>
    ./hardware-configuration.nix

    # Granular Modules
    ../../modules/core/nix.nix
    ../../modules/core/system.nix
    ../../modules/core/user.nix
    ../../modules/core/packages.nix
    ../../modules/core/flakes.nix
    ../../modules/desktop/hyprland.nix
    ../../modules/hardware/audio.nix
    ../../modules/services/tailscale.nix
    # Note: virtualisation.nix is NOT imported here since the laptop can't handle it.
  ];

  # Bootloader
  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.devices = ["nodev"];
  boot.loader.grub.useOSProber = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";
  networking.networkmanager = {
    enable = true;
    dns = "default";
  };

  # Laptop constraint: Wireless and Bluetooth enabled
  networking.wireless.enable = true;
  hardware.bluetooth.enable = true;

  # Keymap and display manager
  services.xserver = {
    enable = false;
    xkb = { layout = "us"; variant = "intl"; };
    displayManager.gdm.enable = false;
    displayManager.lightdm.enable = false;
    displayManager.sddm.enable = false;
  };
  console.keyMap = "us-acentos";
  services.displayManager.sddm.enable = false;

  # Hardware specifics
  hardware = {
    opengl.enable = true;
    keyboard.qmk.enable = true;
  };
  services.udev.packages = [ pkgs.via ];

  # Laptop extra packages
  environment.systemPackages = with pkgs; [
    blueberry
  ];

  # Removed: boot.kernelPackages = pkgs.linuxPackages_6_6; to allow rollback to default kernel.

  system.stateVersion = "25.05";
}