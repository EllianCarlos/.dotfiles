# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      <home-manager/nixos>
    ];

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.devices = ["nodev"];
  boot.loader.grub.useOSProber = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking = {
    networkmanager = {
      enable = true;
      dns = "default";
    };
    wireless.enable = false;
  };

  # Set your time zone.
  time.timeZone = "America/Sao_Paulo";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "pt_BR.UTF-8";
    LC_IDENTIFICATION = "pt_BR.UTF-8";
    LC_MEASUREMENT = "pt_BR.UTF-8";
    LC_MONETARY = "pt_BR.UTF-8";
    LC_NAME = "pt_BR.UTF-8";
    LC_NUMERIC = "pt_BR.UTF-8";
    LC_PAPER = "pt_BR.UTF-8";
    LC_TELEPHONE = "pt_BR.UTF-8";
    LC_TIME = "pt_BR.UTF-8";
  };

  # Configure keymap in X11
  # be careful xserver also has a shitty login screen
  services.xserver = {
    enable = false;
    layout = "br";
    xkb = {
      layout = "br";
      variant = "";
    };
    displayManager = {
      gdm.enable = false;
      lightdm.enable = false;
      sddm.enable = false;
    };
  };

  console.keyMap = "br-abnt";

  services.displayManager.sddm.enable = false;

  # Save volume state on shutdown
  hardware.pulseaudio.enable = true;
  hardware.pulseaudio.package = pkgs.pulseaudioFull;
  nixpkgs.config.pulseaudio = true; ## to change default sink pacmd set-default-sink SINK_NUMBER  ex: pacmd set-default-sink 4
  sound.enable = true;

  # Allow zsh
  programs.zsh.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.elliancarlos = {
    isNormalUser = true;
    description = "Ellian Carlos";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [];
    shell = pkgs.zsh;
  };

  # Visual Environment
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk pkgs.xdg-desktop-portal-hyprland ];
  xdg.portal.wlr.enable = true;

  programs.hyprland.enable = true;
  programs.hyprland.xwayland.enable = true;

  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
    NIXOS_OZONE_WL = "1";
  };

  security.rtkit.enable = true;
  services.pipewire = {
	  enable = true;
	  wireplumber = {
		  enable = true;
	  };
  };




  # Fonts
  fonts.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" ]; })
    font-awesome
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    liberation_ttf
  ];
  


  hardware = {
    opengl.enable = true;
    mwProCapture.enable = true;
    # Configurable keyboards
    keyboard.qmk.enable = true;
  };

  services.udev.packages = [ pkgs.via ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.allowUnfreePredicate = _: true;

  system.autoUpgrade.enable  = true;
  system.autoUpgrade.allowReboot  = true;

  # Allow for nix flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "root" "elliancarlos" ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
     git
     kitty
     zsh
     nerdfonts
     
     # writers
     obsidian

     # webbrowsers
     firefox
     qutebrowser

     # programs utils
     killall
     bottom

     ## find files and directories
     ripgrep
     fd

     ## print, select, copy
     grim
     slurp
     wl-clipboard

     # coding
     vim
     neovim
     jetbrains-toolbox
     
     # env setup
     waybar
     # wofi - home-manager
     hyprlock
     hyprpaper
     hypridle
     brightnessctl

     # screen sharing
     pipewire
     wireplumber
     xdg-desktop-portal-hyprland
     xwaylandvideobridge

     # gaming
     steam
     discord

     # music
     spotify

     # formatter test
     nixfmt-rfc-style

     # developer tools
     devenv

     # video player
     mplayer

     # image viewer
     sxiv

     # qmk and keyboards
     via
     vial
  ];

  programs.git = {
    enable = true;
  };
  
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
  };

  home-manager.users.elliancarlos = import /home/elliancarlos/.config/home-manager/home.nix;

  programs.direnv.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
