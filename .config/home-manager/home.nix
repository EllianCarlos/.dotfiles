{
  config,
  lib,
  pkgs,
  osConfig ? null,
  ...
}:
let
  pins = import ./pins.nix;
  claude-code-flake = builtins.getFlake "github:${pins.claude-code-nix.owner}/${pins.claude-code-nix.repo}/${pins.claude-code-nix.rev}";
  agentSkillsFlake = builtins.getFlake "github:${pins.agent-skills-nix.owner}/${pins.agent-skills-nix.repo}/${pins.agent-skills-nix.rev}";
in
{
  imports = [
    agentSkillsFlake.homeManagerModules.default

    ./modules/packages.nix

    ./modules/shell/zsh.nix
    ./modules/editor/neovim.nix
    ./modules/mail

    ./modules/desktop/theme.nix
    ./modules/desktop/dotfiles.nix
    ./modules/desktop/wayland.nix
    ./modules/desktop/input-method.nix

    ./modules/hardware/g535-audio.nix
    ./modules/dev/pin-check.nix

    ./modules/ai/claude-code.nix
    ./modules/ai/antigravity.nix
    ./modules/ai/herdr.nix
    ./modules/ai/skills.nix
  ];

  # --- Identity -------------------------------------------------------------
  home.username = "elliancarlos";
  home.homeDirectory = "/home/elliancarlos";
  home.stateVersion = "25.05";

  nixpkgs.overlays = [ claude-code-flake.overlays.default ];


  # --- Home Manager itself ----------------------------------------------------
  programs.home-manager.enable = true;
}
