{ config, pkgs, ... }:

{
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

  # Common Packages (System-level & Virtualization)
  environment.systemPackages = with pkgs; [
    git zsh vim
    killall bottom ripgrep fd
    wl-clipboard wireplumber
    brightnessctl nixfmt-rfc-style
    via vial wget curl
  ];

  # Basic tools
  programs.git.enable = true;
  programs.direnv.enable = true;
}