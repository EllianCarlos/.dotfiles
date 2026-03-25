{ config, pkgs, ... }:
let
  claude-code-flake = builtins.getFlake "github:sadjow/claude-code-nix";
in
{
  nixpkgs.config.allowUnfree = true;

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "elliancarlos";
  home.homeDirectory = "/home/elliancarlos";
  home.stateVersion = "25.05";

  nixpkgs.overlays = [ claude-code-flake.overlays.default ];

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    oh-my-zsh

    # User Applications moved from system
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

    # Wayland/Hyprland User Tools
    grim
    slurp
    waybar
    hyprlock
    hyprpaper
    hypridle

    # xclip
    # xsel

    zsh-powerlevel10k

    # gemini-cli
    # kiro
    # code-cursor
    claude-code

    cliphist # Clipboard manager
    libnotify # Desktop notifications
    wl-clipboard # Wayland clipboard utilities

    xournalpp

    libvirt
    libguestfs-with-appliance
    guestfs-tools
    wget
  ];

  xdg.configFile = {
    "hypr".source = ../hypr;
    "kitty".source = ../kitty;
    "waybar".source = ../waybar;
    "bottom".source = ../bottom;
    "nvim".source = ../nvim;
    "wofi".source = ../wofi;
    "neofetch".source = ../neofetch;
    "wallpapers".source = ../wallpapers;
    "background".source = ../background;
  };

  home.pointerCursor = {
    gtk.enable = true;
    # x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  gtk = {
    enable = true;
    theme = {
      package = pkgs.catppuccin-gtk;
      name = "catppuccin-mocha-lavender-standard"; # Or your preferred flavor
    };
    cursorTheme = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
    };
  };


  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;
    ".p10k.zsh".source = ./p10k.zsh;
    ".ticker.yaml".source = ../.ticker.yaml;
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  home.sessionVariables = {
    GTK_IM_MODULE = "cedilla";
    QT_IM_MODULE = "cedilla";
  };

  programs.zsh = {
    enable = true;

    localVariables = {
      ZSH_DISABLE_COMPFIX = "true";
    };

    shellAliases = {
      la = "ls -la";
      ll = "ls -l";
      v = "nvim";
      # Update NixOS by copying the local config to /etc/nixos and then rebuilding
      update = "sudo cp -r ~/Projects/.dotfiles/nixos/* /etc/nixos/ && sudo nixos-rebuild switch";
      # Quick garbage collection
      gc = "nix-collect-garbage -d && sudo nix-collect-garbage -d";
    };

    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    initContent = ''
      if [[ -r "$\{XDG_CACHE_HOME:-$HOME/.cache\}/p10k-instant-prompt-$\{(%):-%n\}.zsh" ]]; then
        source "$\{XDG_CACHE_HOME:-$HOME/.cache\}/p10k-instant-prompt-$\{(%):-%n\}.zsh"
      fi
    '';

    initExtra = ''
      [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
    '';

    # zplug = {
    #     enable=true;
    #     plugins = [
    #       { name = "romkatv/powerlevel10k"; tags = [ as:theme depth:1 ]; } # Installations with additional options. For the list of options, please refer to Zplug README.
    #     ];
    # };

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

      theme = "";
    };

    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
      {
        name = "p10k-config";
        src = ./.;
        file = ".p10k.zsh";
      }
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

  programs.wofi = {
    enable = true;
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    extraPackages = with pkgs; [
      gcc
      gnumake
      unzip
      wget
      curl
      tree-sitter

      fzf
      trash-cli
      diffutils
      ghostscript
      tectonic

      lua-language-server
      stylua

      nil
      nixpkgs-fmt

      nodejs_22

      vscode-langservers-extracted

      nodePackages.prettier
      prettierd
      eslint_d
      biome
      stylelint

      pyright
      black

      rust-analyzer
      rustfmt

      kotlin-language-server
      ktlint

      shfmt
      shellcheck

      ast-grep
      detekt
      nimlangserver
    ];
  };

  # Claude Code settings (permissions only - MCP servers go in ~/.claude.json)
  home.activation.claudeSettings =
    let
      claudeSettingsFile = pkgs.writeText "claude-settings.json" (builtins.toJSON {
        permissions = {
          allow = [
            "WebFetch(domain:github.com)"
            "WebFetch(domain:raw.githubusercontent.com)"
            "Bash(nix-channel --list)"
          ];
        };
      });
      # MCP servers must be in ~/.claude.json (not settings.json)
      # env.PATH must include nodejs bin dir so spawned packages can find `node`
      nodePath = "${pkgs.nodejs_22}/bin";
      claudeMcpFile = pkgs.writeText "claude.json" (builtins.toJSON {
        mcpServers = {
          context7 = {
            command = "${pkgs.nodejs_22}/bin/npx";
            args = [ "-y" "@upstash/context7-mcp@latest" ];
            env = { PATH = "${pkgs.nodejs_22}/bin:/usr/bin:/bin"; };
          };
          github = {
            command = "${pkgs.nodejs_22}/bin/npx";
            args = [ "-y" "@modelcontextprotocol/server-github" ];
            env = { PATH = "${pkgs.nodejs_22}/bin:/usr/bin:/bin"; };
          };
          sequential-thinking = {
            command = "${pkgs.nodejs_22}/bin/npx";
            args = [ "-y" "@modelcontextprotocol/server-sequential-thinking" ];
            env = { PATH = "${pkgs.nodejs_22}/bin:/usr/bin:/bin"; };
          };
          playwright = {
            command = "${pkgs.nodejs_22}/bin/npx";
            args = [ "-y" "@playwright/mcp" ];
            env = { PATH = "${pkgs.nodejs_22}/bin:/usr/bin:/bin"; };
          };
        };
      });
    in
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "$HOME/.claude"
      rm -f "$HOME/.claude/settings.json"
      cp ${claudeSettingsFile} "$HOME/.claude/settings.json"
      chmod 644 "$HOME/.claude/settings.json"

      if [ -f "$HOME/.claude.json" ]; then
        ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$HOME/.claude.json" ${claudeMcpFile} > "$HOME/.claude.json.tmp"
        mv "$HOME/.claude.json.tmp" "$HOME/.claude.json"
      else
        cp ${claudeMcpFile} "$HOME/.claude.json"
      fi
      chmod 644 "$HOME/.claude.json"
    '';

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
