{ config, pkgs, lib, ... }:

let 
  lanzaboote = builtins.getFlake "github:nix-community/lanzaboote/v1.0.0";
  system = "x86_64-linux";
in
{
  imports = [ 
    <home-manager/nixos>
    ./hardware-configuration.nix
    ../../server.nix
    lanzaboote.nixosModules.lanzaboote

    # Granular Modules
    ../../modules/core/nix.nix
    ../../modules/core/system.nix
    ../../modules/core/user.nix
    ../../modules/core/packages.nix
    ../../modules/core/flakes.nix
    ../../modules/desktop/hyprland.nix
    ../../modules/hardware/audio.nix
    ../../modules/services/tailscale.nix
    ../../modules/services/virtualisation.nix
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };

  boot.kernelPackages = pkgs.linuxPackages_6_6;
  boot.kernelParams = [ "nowatchdog" ];
  systemd.settings.Manager = {
    RuntimeWatchdogSec = 0;
    ShutdownWatchdogSec = 0;
  };

  # Auto login
  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "Hyprland";
        user = "elliancarlos";
      };
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
        user = "greeter";
      };
    };
  };

  networking.hostName = "carmenere";
  networking.networkmanager = {
    enable = true;
    dns = "default";
  };
  networking.nat = {
    enable = true;
    internalInterfaces = [ "virbr0" ];
  };

  # Desktop constraint: NO wireless or bluetooth
  networking.wireless.enable = lib.mkForce false;
  hardware.bluetooth.enable = lib.mkForce false;

  # Keymap and display manager
  services.xserver = {
    enable = false;
    xkb = { layout = "us"; variant = "intl"; };
    displayManager.lightdm.enable = false;
  };
  console.keyMap = "us-acentos";
  services.displayManager.sddm.enable = false;
  services.displayManager.gdm.enable = false;

  # Hardware specifics
  hardware = {
    opengl.enable = true;
    mwProCapture.enable = true;
    keyboard.qmk.enable = true;
    graphics = {
      enable = true;
      extraPackages = with pkgs; [ rocmPackages.clr.icd ];
    };
  };
  services.udev.packages = [ pkgs.via ];

  # Desktop extra packages
  environment.systemPackages = with pkgs; [
    sbctl
    (import <nixos-stable> { 
      inherit system; 
      config.allowUnfree = true; 
    }).qemu_full
  ];

  # System Upgrade
  system.autoUpgrade.enable  = true;
  system.autoUpgrade.allowReboot  = true;

  # Gaming
  programs.steam = {
    enable = false; 
    remotePlay.openFirewall = true; 
    dedicatedServer.openFirewall = true; 
    localNetworkGameTransfers.openFirewall = true; 
  };

  system.stateVersion = "25.05";
}