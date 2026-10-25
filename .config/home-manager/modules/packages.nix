# Everything installed into the user profile, plus the build-time
# verifiers that must fail the build rather than warn at run time.
{
  pkgs,
  lib,
  osConfig ? null,
  ...
}:
let
  custom = import ../pkgs { inherit pkgs; };

  checkFontFamilies = import ../checks/font-families.nix {
    inherit pkgs lib osConfig;
  };

  pins = import ../pins.nix;
  zenBrowserFlake = builtins.getFlake "github:${pins.zen-browser.owner}/${pins.zen-browser.repo}/${pins.zen-browser.rev}";

  opencodePinned =
    (import (
      builtins.fetchTarball "https://github.com/${pins.opencode-nixpkgs-pin.owner}/${pins.opencode-nixpkgs-pin.repo}/archive/${pins.opencode-nixpkgs-pin.rev}.tar.gz"
    ) { inherit (pkgs) system; }).opencode;

  zoteroPinned =
    (import (
      builtins.fetchTarball "https://github.com/${pins.zotero-nixpkgs-pin.owner}/${pins.zotero-nixpkgs-pin.repo}/archive/${pins.zotero-nixpkgs-pin.rev}.tar.gz"
    ) { inherit (pkgs) system; }).zotero;
in
{
  imports = [ zenBrowserFlake.homeModules.beta ];

  nixpkgs.config.allowUnfree = true;

  home.file.".ticker.yaml".source = ../../.ticker.yaml;

  programs.zen-browser = {
    enable = true;

    # Catppuccin theme (catppuccin/zen-browser), symlinked into the profile's
    # chrome/catppuccin and loaded via userChrome/userContent imports.
    profiles.default.presets.catppuccin = {
      enable = true;
      flavor = "Mocha"; # Frappe | Latte | Macchiato | Mocha
      accent = "Mauve"; # Blue, Flamingo, Green, Lavender, Maroon, Mauve, ...
    };

    # Betterfox for Zen (yokoffing/Betterfox zen/user.js, aka BetterZen):
    # privacy/telemetry/performance prefs applied as mkDefault settings —
    # any profile `settings` entry wins.
    profiles.default.presets.betterfox.enable = true;

    # arkenfox for Zen (arkenfox/user.js)
    profiles.default.presets.arkenfox.enable = true;
  };

  home.packages =
    with pkgs;
    [
      oh-my-zsh

      # --- Applications ---
      wezterm
      kitty
      obsidian
      firefox
      discord
      spotify
      mplayer
      sxiv
      tmux
      devenv
      ticker
      zip
      stress-ng
      jq
      vicinae
      tuicr
      super-productivity
      pass
      google-chrome
      zoteroPinned

      # --- Linux kernel review (lore.kernel.org) ---
      b4 # fetch + review (b4 review TUI) patch series from public-inbox
      public-inbox # provides `lei`, for search/pull of kernel-list mail
      delta # readable diffs when reading patches in the terminal

      # --- Wayland / Hyprland ---
      grim
      slurp
      waybar
      hyprlock
      hyprpaper
      hyprshell
      hypridle

      zsh-powerlevel10k

      # --- Audio ---
      custom.wb-headset

      # --- AI Agents ---
      antigravity-cli
      # kiro
      # code-cursor
      claude-code
      custom.mnemon
      custom.engram
      opencodePinned
      custom.dsh
      custom.omniroute

      # --- Herdr / Collie (github.com/AltanS/collie) ---
      bun
      herdr
      python3 # only needed by herdr
      (writeShellScriptBin "collie" ''
        for c in "$HOME"/.config/herdr/plugins/github/herdr.collie-*/bin/collie; do
          [ -x "$c" ] && latest="$c"
        done
        [ -n "$latest" ] || { echo "collie: herdr plugin not installed" >&2; exit 1; }
        exec "$latest" "$@"
      '')

      cliphist # Clipboard manager
      libnotify # Desktop notifications
      wl-clipboard # Wayland clipboard utilities

      xournalpp

      wget
    ]
    ++ [
      # --- Verifiers ---
      checkFontFamilies
    ]
    ++ custom.loop-tools;
}
