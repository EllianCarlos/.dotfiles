{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "elliancarlos";
  home.homeDirectory = "/home/elliancarlos";
  home.stateVersion = "24.05"; 

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages =  with pkgs; [
    oh-my-zsh
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  programs.zsh = {
    enable = true;
    shellAliases = {
      la = "ls -la";
      update = "sudo nixos-rebuild switch";
    };
    autosuggestion.enable = true;
    
    oh-my-zsh = {
      enable = true;
      plugins = ["git"];
      theme = "robbyrussell";
    };
  };

  programs.wofi = {
    enable = true;
  };


  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
