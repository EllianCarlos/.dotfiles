# My Dotfiles

This repository manages my system configurations, bridging system-level configuration (NixOS) and user-level environment management (Home Manager). It uses a modular approach to support multiple hosts cleanly.

## Key Features

*   **Modular NixOS Configuration:** System configurations are broken down into granular, feature-based modules (e.g., `core`, `desktop`, `hardware`, `services`). Hosts opt-in to features by importing specific modules, eliminating the need for monolithic setups or hacky overrides.
*   **Multi-Host Support:** Distinct configurations for my Desktop and Laptop are maintained under `nixos/hosts/`. They share the core modules but define their own hardware profiles, networking constraints, and bootloader setups.
*   **Separation of Concerns:** 
    *   **NixOS (`/nixos`):** Strictly handles system bootstrap, hardware drivers, audio (Pipewire), networking, core CLI utilities, and virtualization.
    *   **Home Manager (`.config/home-manager`):** Manages user-specific applications (browsers, media, coding tools), terminal setup (Zsh, Neovim), visual environment (Catppuccin GTK), and automatically symlinks dotfiles for Hyprland, Waybar, Kitty, etc.
*   **Declarative Dotfiles:** Configuration folders for apps inside `.config/` are automatically mapped to the user's home directory by Home Manager via `xdg.configFile`, keeping everything tracked in Git.

---

## Deployment

### 1. NixOS System Configuration

To apply the configuration, we copy the modular structure directly into `/etc/nixos` and then point the default `configuration.nix` to the desired host. This ensures NixOS can easily resolve all the relative paths for the modules without relying on build flags.

First, back up any existing configuration and copy the repository's `nixos` folder:
```bash
sudo rm -rf /etc/nixos.bak
sudo mv /etc/nixos /etc/nixos.bak
sudo cp -r ~/Projects/.dotfiles/nixos /etc/nixos
```

**For the Laptop:**
```bash
sudo ln -sf /etc/nixos/hosts/laptop/configuration.nix /etc/nixos/configuration.nix
sudo nixos-rebuild switch
```

**For the Desktop:**
```bash
sudo ln -sf /etc/nixos/hosts/desktop/configuration.nix /etc/nixos/configuration.nix
sudo nixos-rebuild switch
```

### 2. User Environment & Dotfiles (Home Manager)

The Home Manager configuration manages user packages and automatically handles the symlinking of the `.config/*` directories.

Because Home Manager is integrated directly as a NixOS module (via `modules/core/user.nix`), **you do not use the standalone `home-manager` command**. 

Any changes made to `~/.config/home-manager/home.nix` or the related dotfiles are automatically applied alongside your system updates. 

To apply user settings, packages, and symlink updates:
```bash
sudo nixos-rebuild switch
```
