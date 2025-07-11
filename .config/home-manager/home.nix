{ config, pkgs, ... }:

{
  home.username = "elliancarlos";
  home.homeDirectory = "/home/elliancarlos";
  home.stateVersion = "24.05"; 

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages =  with pkgs; [
    oh-my-zsh

    xclip
    xsel

    zsh-powerlevel10k

    ticker
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

    localVariables = {
      ZSH_DISABLE_COMPFIX = "true";
    };

    shellAliases = {
      la = "ls -la";
      update = "sudo nixos-rebuild switch";
    };


    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    zplug = {
        enable=true;
        plugins = [
          { name = "romkatv/powerlevel10k"; tags = [ as:theme depth:1 ]; } # Installations with additional options. For the list of options, please refer to Zplug README.
        ];
    };

    initExtra = '' 
      [[ ! -f ${./.p10k.zsh} ]] || source ${./.p10k.zsh}
    '';

    oh-my-zsh = {
      enable = true;

      plugins = [
        "git"
        "fzf"
        "z"
        "copyfile"
        "history"
        "dirhistory"
      ];

      theme = "robbyrussell";
    };

    plugins = [
        {
          name = "zsh-completions";
          src = pkgs.fetchFromGitHub {
            owner = "zsh-users";
            repo = "zsh-completions";
            rev = "0.35.0";
            hash = "sha256-GFHlZjIHUWwyeVoCpszgn4AmLPSSE8UVNfRmisnhkpg=";
          };
        }
        {
          name = "zsh-syntax-highlighting";
          src = pkgs.fetchFromGitHub {
            owner = "zsh-users";
            repo = "zsh-syntax-highlighting";
            rev = "0.8.0";
            hash = "sha256-iJdWopZwHpSyYl5/FQXEW7gl/SrKaYDEtTH9cGP7iPo=";
          };
        }
    ];
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };


  programs.wofi = {
    enable = true;
  };


  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
