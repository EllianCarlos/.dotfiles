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

  custom = import ./pkgs { inherit pkgs; };

in
{
  imports = [
    agentSkillsFlake.homeManagerModules.default
    ./modules/packages.nix
    ./modules/shell/zsh.nix
    ./modules/editor/neovim.nix
    ./modules/desktop/theme.nix
    ./modules/desktop/dotfiles.nix
    ./modules/desktop/wayland.nix
    ./modules/desktop/input-method.nix
    ./modules/ai/claude-code.nix
    ./modules/ai/antigravity.nix
    ./modules/ai/herdr.nix
    ./modules/ai/skills.nix
    ./pin-check.nix
    ./g535-audio.nix
  ];

  # --- Identity -------------------------------------------------------------
  home.username = "elliancarlos";
  home.homeDirectory = "/home/elliancarlos";
  home.stateVersion = "25.05";

  nixpkgs.overlays = [ claude-code-flake.overlays.default ];


  programs.neomutt = {
    enable = true;
    vimKeys = true;
    sort = "threads";
    extraConfig = ''
      set timeout = 3;
      set mail_check = 60;
      set collapse_all = yes;
      set use_threads = yes;
      set sort = "reverse-last-date-received";
      set delete = ask-yes;
    '';
  };

  accounts.email.accounts = import ./email.nix { inherit pkgs; };

  programs.mbsync.enable = true;

  programs.gpg.enable = true;

  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-curses;
  };

  # --- Home Manager itself ----------------------------------------------------
  programs.home-manager.enable = true;
}
