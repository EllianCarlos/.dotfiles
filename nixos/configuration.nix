  # Edit this configuration file to define what should be installed on
  # your system.  Help is available in the configuration.nix(5) man page
  # and in the NixOS manual (accessible by running ‘nixos-help’).

  { config, pkgs, lib, ... }:

  let 
    cursor-flake = builtins.getFlake "github:omarcresp/cursor-flake";
    lanzaboote = builtins.getFlake "github:nix-community/lanzaboote/v1.0.0";
    system = "x86_64-linux";
  in
  {
    imports =
      [ # Include the results of the hardware scan.
        ./hardware-configuration.nix
        <home-manager/nixos>
        ./server.nix
        lanzaboote.nixosModules.lanzaboote
      ];
    

    # Bootloader.
    # boot.loader.grub.enable = true;
    # boot.loader.grub.efiSupport = true;
    # boot.loader.grub.devices = ["nodev"];
    # boot.loader.grub.useOSProber = true;
    # boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };

    boot.kernelPackages = pkgs.linuxPackages_6_6;

    # Disable Watchdog (DON'T DO THIS AT HOME)
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

    networking.hostName = "carmenere"; # Define your hostname. (Change this for laptop)
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
      nat = {
        enable = true;
        internalInterfaces = [ "virbr0" ];
      };
      # LAPTOP: Remove the mkForce or set to true if using Wi-Fi without NetworkManager
      wireless.enable = lib.mkForce false;
    };

    # LAPTOP: Add power management
    # services.upower.enable = true;
    # services.tlp.enable = true; # Or services.auto-cpufreq.enable = true;
    # services.libinput.enable = true; # Touchpad support

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
      xkb = {
        layout = "us";
        variant = "intl";
      };
      displayManager = {
        lightdm.enable = false;
      };
    };

    console.keyMap = "us-acentos";

    services.displayManager.sddm.enable = false;
    services.displayManager.gdm.enable = false;

    services.tailscale = {
      enable = true;
    };

    networking.nftables.enable = true;
    networking.firewall = {
      enable = true;
      # Always allow traffic from your Tailscale network
      checkReversePath = "loose";
      trustedInterfaces = [ "tailscale0" "virbr0" ];
      # Allow the Tailscale UDP port through the firewall
      allowedUDPPorts = [ config.services.tailscale.port ];
    };

    # 2. Force tailscaled to use nftables (Critical for clean nftables-only systems)
    # This avoids the "iptables-compat" translation layer issues.
    systemd.services.tailscaled.serviceConfig.Environment = [ 
      "TS_DEBUG_FIREWALL_MODE=nftables" 
    ];

    # 3. Optimization: Prevent systemd from waiting for network online 
    # (Optional but recommended for faster boot with VPNs)
    systemd.network.wait-online.enable = false; 
    boot.initrd.systemd.network.wait-online.enable = false;


    # Save volume state on shutdown
    # hardware.pulseaudio.enable = true;
    # hardware.pulseaudio.package = pkgs.pulseaudioFull;
    # nixpkgs.config.pulseaudio = true; ### Conflicts with pipe wire

    # Allow zsh
    programs.zsh.enable = true;

    # Define a user account. Don't forget to set a password with ‘passwd’.
    users.users.elliancarlos = {
      isNormalUser = true;
      description = "Ellian Carlos";
      extraGroups = [ "networkmanager" "wheel" "libvirtd" "libvirt-qemu" "wheel" "video" "render" ];
      packages = with pkgs; [];
      shell = pkgs.zsh;
    };

    # Visual Environment
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
      config.common.default = "*";
    };

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      alsa.support32Bit = true;
    };


    programs.hyprland.enable = true;
    programs.hyprland.xwayland.enable = true;

    environment.sessionVariables = {
      WLR_NO_HARDWARE_CURSORS = "1";
      NIXOS_OZONE_WL = "1";
    };

    security.rtkit.enable = true;
    services.pulseaudio.enable = lib.mkForce false;


    # Fonts
    fonts.packages = with pkgs; [
      nerd-fonts.fira-code
      nerd-fonts.droid-sans-mono
      font-awesome
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      liberation_ttf
    ];
    

    hardware = {
      opengl.enable = true;
      mwProCapture.enable = true;
      # Configurable keyboards
      keyboard.qmk.enable = true;
      graphics = {
        enable = true;
        # LAPTOP: Replace with appropriate drivers for Intel/NVIDIA if needed
        extraPackages = with pkgs; [
          rocmPackages.clr.icd
        ];
      };
    };

    services.udev.packages = [ pkgs.via ];

    # Allow unfree packages
    nixpkgs.config.allowUnfree = true;
    nixpkgs.config.allowBroken = true;
    nixpkgs.config.allowUnfreePredicate = _: true;

    system.autoUpgrade.enable  = true;
    system.autoUpgrade.allowReboot  = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "root" "elliancarlos" ];

  environment.systemPackages = with pkgs; [
    git
    kitty
    zsh

		# writers
    obsidian

		# webbrowsers
    firefox

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
		# neovim - home-manager
    jetbrains-toolbox

		# env setup
    waybar
		# wofi - home-manager
    hyprlock
    hyprpaper
    hypridle
    brightnessctl

		# screen sharing
    wireplumber
    xdg-desktop-portal-hyprland

		# gaming
    discord

		# music
    spotify

		# formatter test
    nixfmt

		# developer tools
    devenv
    cursor-flake.packages.${system}.default

		# video player
    mplayer

		# image viewer
    sxiv

		# qmk and keyboards
    via
    vial

		# Boot Utils
    sbctl

    (import <nixos-stable> { 
      inherit system; 
      config.allowUnfree = true; 
    }).qemu_full

    tailscale
    tmux
  ];

  programs.git = {
    enable = true;
  };
  
  programs.steam = {
    enable = false; ## Not gaming on linux right now because my windows has more free space
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
  };

  home-manager.users.elliancarlos = import /home/elliancarlos/.config/home-manager/home.nix;
  home-manager.backupFileExtension = "backup";

  programs.direnv.enable = true;

  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  virtualisation.libvirtd = {
    enable = true;
  };
  programs.virt-manager.enable = true;

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
  system.stateVersion = "25.05"; # Did you read the comment?
}
