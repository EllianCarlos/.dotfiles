{ config, lib, pkgs, osConfig ? null, ... }:
let
  pins = import ./pins.nix;
  claude-code-flake = builtins.getFlake "github:${pins.claude-code-nix.owner}/${pins.claude-code-nix.repo}/${pins.claude-code-nix.rev}";
  agentSkillsFlake = builtins.getFlake "github:${pins.agent-skills-nix.owner}/${pins.agent-skills-nix.repo}/${pins.agent-skills-nix.rev}";

  # kitty and waybar name fonts as plain strings that fontconfig resolves at
  # runtime. Fontconfig never fails: an unknown family silently falls back to
  # whatever else it can find, so a typo or an upstream font rename degrades
  # quietly instead of erroring -- which is how kitty.conf asked for the
  # never-installed "Fira Code" for over a year while actually rendering
  # DejaVu Sans Mono, with icons served by the shrunken *Mono* Nerd Font.
  #
  # Nix cannot catch that by itself: xdg.configFile copies these files as
  # opaque bytes and has no idea they name a font. So extract the families the
  # configs actually ask for and fail the build when the installed font
  # packages do not provide them. Compares against osConfig.fonts.packages,
  # the real system font set -- a hand-written list of expected names would
  # just repeat whatever name is already wrong in the config, and pass.
  fontPackages =
    if osConfig == null
    then throw "home.nix: osConfig is unavailable, so the font-family check cannot read fonts.packages. Remove the check or give it an explicit package list rather than letting it silently pass."
    else osConfig.fonts.packages;

  checkFontFamilies = pkgs.runCommand "check-font-families"
    { nativeBuildInputs = [ pkgs.fontconfig.bin ]; } ''
    dirs=""
    for d in ${lib.escapeShellArgs (map (p: "${p}/share/fonts") fontPackages)}; do
      [ -d "$d" ] && dirs="$dirs $d"
    done

    # stderr is only sandbox noise about unwritable font caches
    fc-scan --format '%{family}\n' $dirs 2>/dev/null \
      | tr ',' '\n' | sed 's/^[ "]*//; s/[ "]*$//' | grep -v '^$' | sort -u > installed

    # font_family in kitty.conf, font-family in waybar's stylesheet
    {
      sed -n 's/^font_family[[:space:]]\+//p' ${../kitty/kitty.conf}
      sed -n 's/.*font-family:[[:space:]]*\([^;]*\);.*/\1/p' ${../waybar/style.css}
    } | tr ',' '\n' | sed 's/^[ "]*//; s/[ "]*$//' | grep -v '^$' | sort -u > wanted

    missing=$(grep -Fxv -f installed wanted || true)
    if [ -n "$missing" ]; then
      echo "" >&2
      echo "error: these font families are referenced by config, but no installed" >&2
      echo "font package provides them (fontconfig would silently fall back):" >&2
      echo "" >&2
      echo "$missing" | while IFS= read -r fam; do
        echo "  - $fam" >&2
        # squash case and spaces so "Fira Code" suggests "FiraCode Nerd Font"
        key=$(printf '%s' "$fam" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
        awk -v k="$key" \
          '{ n = tolower($0); gsub(/ /, "", n); if (index(n, k)) print "      did you mean: " $0 }' \
          installed >&2
      done
      echo "" >&2
      echo "($(wc -l < installed) families installed; run 'fc-list : family' to list them)" >&2
      exit 1
    fi

    mkdir -p "$out"
  '';
  mnemon = pkgs.stdenv.mkDerivation {
    pname = "mnemon";
    version = "0.1.3";
    src = pkgs.fetchurl {
      url = "https://github.com/mnemon-dev/mnemon/releases/download/v0.1.3/mnemon_0.1.3_linux_amd64.tar.gz";
      hash = "sha256-38pH9YNNSv0yycdufodqvJ+8ofrI5QFm9qm6NnPOQbA=";
    };
    unpackPhase = "tar xzf $src";
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/bin
      install -m755 mnemon $out/bin/mnemon
    '';
  };
in
{
  imports = [
    agentSkillsFlake.homeManagerModules.default
    ./skills.nix
    ./pin-check.nix
  ];

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
    zip
    stress-ng
    jq

    # Wayland/Hyprland User Tools
    grim
    slurp
    waybar
    hyprlock
    hyprpaper
    hypridle

    zsh-powerlevel10k

    gemini-cli
    # kiro
    # code-cursor
    claude-code
    mnemon

    cliphist # Clipboard manager
    libnotify # Desktop notifications
    wl-clipboard # Wayland clipboard utilities

    xournalpp

    libvirt
    libguestfs-with-appliance
    guestfs-tools
    wget

    super-productivity
  ] ++ [
    # Not a program -- an empty package whose build fails if the font families
    # named in kitty.conf / waybar style.css are not actually installed.
    checkFontFamilies
  ] ++ (import ./loop-tools.nix { inherit pkgs; });

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
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
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

    # mnemon: manage hooks/prompt/skill declaratively instead of running
    # `mnemon setup` at activation. The vendored copies fix two upstream bugs:
    # hooks use `#!/usr/bin/env bash` (NixOS has no /bin/bash), and guide.md
    # stores memories via the real `subagent_type="general-purpose"` agent
    # (mnemon ships a non-existent "Bash" agent). The data store
    # (~/.mnemon/data) is stateful and self-initialises on first use.
    ".mnemon/prompt/guide.md".source = ./mnemon/guide.md;
    ".mnemon/prompt/skill.md".source = ./mnemon/skill.md;
    ".claude/skills/mnemon/SKILL.md".source = ./mnemon/skill.md;
    ".claude/hooks/mnemon/prime.sh" = {
      source = ./mnemon/hooks/prime.sh;
      executable = true;
    };
    ".claude/hooks/mnemon/stop.sh" = {
      source = ./mnemon/hooks/stop.sh;
      executable = true;
    };
    ".claude/hooks/mnemon/user_prompt.sh" = {
      source = ./mnemon/hooks/user_prompt.sh;
      executable = true;
    };

    # nixapply: encodes the edit -> validate -> rebuild -> verify -> reload
    # loop for this repo, so a config change isn't declared fixed before a
    # rebuild actually lands it.
    ".claude/skills/nixapply/SKILL.md".source = ./nixapply/skill.md;

    # PostToolUse: catch broken JSON/Nix syntax right after Edit/Write,
    # instead of discovering it at the next rebuild (a trailing comma in
    # waybar's JSON once broke it outright).
    ".claude/hooks/validate-config.sh" = {
      source = ./hooks/validate-config.sh;
      executable = true;
    };
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

      # Change default sink 
      audio-headset = "audio-to alsa_output.usb-Logitech_G535_Wireless_Gaming_Headset-00.analog-stereo";
      audio-hdmi = "audio-to alsa_output.pci-0000_03_00.1.hdmi-stereo-extra1";
      audio-combine = "audio-to combine-sink";
    };

    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    initContent = ''
      if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
        source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
      fi
    '';

    initExtra = ''
      [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

      audio-to() {
        pactl set-default-sink "$1"
        for i in $(pactl list short sink-inputs | cut -f1); do
          pactl move-sink-input "$i" "$1" 2>/dev/null
        done
      }
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

      prettier
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
      hooksDir = "${config.home.homeDirectory}/.claude/hooks/mnemon";
      claudeHooksDir = "${config.home.homeDirectory}/.claude/hooks";
      claudeSettingsFile = pkgs.writeText "claude-settings.json" (builtins.toJSON {
        permissions = {
          allow = [
            "WebFetch(domain:github.com)"
            "WebFetch(domain:raw.githubusercontent.com)"
            "Bash(nix-channel --list)"

            "Bash(* --version)"
            "Bash(* --help *)"

            # Read-only Hyprland state queries (mutating verbs — keyword,
            # dispatch, reload — are deliberately left out).
            "Bash(hyprctl monitors)"
            "Bash(hyprctl monitors *)"
            "Bash(hyprctl configerrors)"
            "Bash(hyprctl version)"
            "Bash(hyprctl systeminfo)"
            "Bash(hyprctl instances)"
            "Bash(hyprctl dispatchers)"
            "Bash(hyprctl cursorpos)"
            "Bash(hyprctl clients)"
            "Bash(hyprctl clients *)"
            "Bash(hyprctl workspaces)"
            "Bash(hyprctl workspaces *)"
            "Bash(hyprctl activewindow)"
            "Bash(hyprctl activewindow *)"
            "Bash(hyprctl getoption *)"
            "Bash(hyprctl binds)"
            "Bash(hyprctl devices)"

            # Crash inspection and font resolution.
            "Bash(coredumpctl list *)"
            "Bash(coredumpctl info *)"
            "Bash(fc-match *)"
            "Bash(fc-list)"
            "Bash(fc-list *)"

            "Agent(*)"
            "Bash(run_in_backgroun:true)"

            "Bash(mnemon recall *)"
            "Read(*)"

            # Built-in tools with no external side effects: loading a skill's
            # instructions, inspecting/tracking Claude's own subagent tasks,
            # read-only MCP resource listing, code nav/diagnostics, and
            # streaming output of an already-running background process.
            "Skill"
            "TaskCreate"
            "TaskUpdate"
            "TaskGet"
            "TaskList"
            "TaskOutput"
            "ListMcpResourcesTool"
            "ReadMcpResourceTool"
            "ReadMcpResourceDirTool"
            "LSP"
            "Monitor"
            "WebSearch"

            # Broad read-only filesystem commands (secrets protected via deny list below)
            "Bash(ls)"
            "Bash(ls *)"
            "Bash(cat *)"
            "Bash(grep *)"
            "Bash(pwd)"

            # Git (read-only subset; branch/remote/stash kept to exact matches to
            # exclude their destructive subcommands: git branch -D, git remote
            # remove, git stash drop/pop)
            "Bash(git status)"
            "Bash(git status *)"
            "Bash(git diff)"
            "Bash(git diff *)"
            "Bash(git log)"
            "Bash(git log *)"
            "Bash(git show *)"
            "Bash(git remote -v)"
            "Bash(git stash list)"
            "Bash(git branch)"
            "Bash(git branch -a)"
            "Bash(git branch -v)"
            "Bash(git branch --show-current)"

            # System / process info (no destructive flags exist for these commands)
            "Bash(whoami)"
            "Bash(id)"
            "Bash(uname *)"
            "Bash(free *)"
            "Bash(uptime)"
            "Bash(df -h)"
            "Bash(df -h *)"
            "Bash(du *)"
            "Bash(ps *)"
            "Bash(lsblk)"
            "Bash(lsblk *)"
            "Bash(lscpu)"
            "Bash(lsusb)"
            "Bash(lspci)"
            "Bash(hostnamectl)"
            "Bash(hostnamectl status)"

            # systemd status/list only (start/stop/restart and journalctl
            # --vacuum-* are destructive and stay excluded)
            "Bash(systemctl status *)"
            "Bash(systemctl --user status *)"
            "Bash(systemctl list-units *)"
            "Bash(systemctl list-unit-files *)"

            # Nix read-only queries (nixos-rebuild switch / home-manager switch /
            # nix-collect-garbage stay excluded -- those are the existing
            # mutating `update`/`gc` aliases and should keep prompting)
            "Bash(nix flake show *)"
            "Bash(nix flake metadata *)"
            "Bash(nix search *)"
            "Bash(nix-store -q *)"
            "Bash(nix-env -q)"
            "Bash(nix-env --query)"
            "Bash(home-manager --list-generations)"

            # Common dev tool invocations (build/run/test workflows; publish/
            # uninstall/toolchain-mutating subcommands deliberately excluded)
            "Bash(npm install)"
            "Bash(npm install *)"
            "Bash(npm ci)"
            "Bash(npm run *)"
            "Bash(npm test)"
            "Bash(npm test *)"
            "Bash(npm start)"
            "Bash(npm outdated)"
            "Bash(npm outdated *)"
            "Bash(npm list)"
            "Bash(npm list *)"
            "Bash(npm view *)"

            "Bash(bun install)"
            "Bash(bun install *)"
            "Bash(bun add *)"
            "Bash(bun run *)"
            "Bash(bun test)"
            "Bash(bun test *)"
            "Bash(bun x *)"

            "Bash(cargo build)"
            "Bash(cargo build *)"
            "Bash(cargo run)"
            "Bash(cargo run *)"
            "Bash(cargo test)"
            "Bash(cargo test *)"
            "Bash(cargo check)"
            "Bash(cargo check *)"
            "Bash(cargo fmt)"
            "Bash(cargo fmt *)"
            "Bash(cargo clippy)"
            "Bash(cargo clippy *)"
            "Bash(cargo add *)"
            "Bash(cargo doc *)"
            "Bash(rustup show)"
            "Bash(rustup show *)"
            "Bash(rustup toolchain list)"

            "Bash(devenv shell)"
            "Bash(devenv shell *)"
            "Bash(devenv up)"
            "Bash(devenv up *)"
            "Bash(devenv test)"
            "Bash(devenv test *)"
            "Bash(devenv info)"
            "Bash(devenv tasks *)"

            "Bash(direnv status)"
            "Bash(direnv status *)"
            "Bash(direnv reload)"
            "Bash(direnv reload *)"
            "Bash(direnv allow)"
            "Bash(direnv allow *)"

            # More non-breaking nix commands (dry-build/build don't switch/activate)
            "Bash(nix path-info *)"
            "Bash(nix why-depends *)"
            "Bash(nix show-derivation *)"
            "Bash(nix registry list)"
            "Bash(nix eval *)"
            "Bash(nix build --dry-run *)"
            "Bash(nix-instantiate --parse *)"
            "Bash(nix-instantiate --eval *)"
            "Bash(nixos-rebuild dry-build *)"
            "Bash(nixos-rebuild build *)"

            # Built-in read-only tools
            "Grep"
            "Glob"

            # MCP tools from mcp.nix -- read-only subset only. Mutating tools
            # (execute_sql, git_add/checkout/commit/reset, filesystem
            # write/edit/move/create, all github comment/merge/push/delete/create,
            # playwright click/type/fill/evaluate/run_code_unsafe) stay excluded
            # and keep prompting. cockroachdb-cloud is left out entirely -- its
            # tool schema wasn't discoverable to verify what's safe.
            "mcp__postgres__analyze_db_health"
            "mcp__postgres__analyze_query_indexes"
            "mcp__postgres__analyze_workload_indexes"
            "mcp__postgres__explain_query"
            "mcp__postgres__get_object_details"
            "mcp__postgres__get_top_queries"
            "mcp__postgres__list_objects"
            "mcp__postgres__list_schemas"

            "mcp__context7__*"
            "mcp__nixos__*"
            "mcp__sequential-thinking__*"
            "mcp__time__*"

            # obsidian-mestrado/obsidian-second-brain (seekstone) -- read-only
            # tools plus the non-destructive additive writes (append_note,
            # get/append_periodic_note never overwrite existing content).
            # create_note and move_note stay excluded: both take an
            # overwrite:true param that would let Claude silently clobber
            # existing note content, and MCP tool permission rules can't
            # distinguish overwrite:true from false. delete_note,
            # patch_frontmatter, patch_note, replace_in_note also stay
            # excluded and keep prompting.
            "mcp__obsidian-mestrado__search"
            "mcp__obsidian-mestrado__query_notes"
            "mcp__obsidian-mestrado__read_note"
            "mcp__obsidian-mestrado__list_notes"
            "mcp__obsidian-mestrado__list_tags"
            "mcp__obsidian-mestrado__outline_note"
            "mcp__obsidian-mestrado__get_backlinks"
            "mcp__obsidian-mestrado__get_links"
            "mcp__obsidian-mestrado__append_note"
            "mcp__obsidian-mestrado__get_periodic_note"
            "mcp__obsidian-mestrado__append_periodic_note"

            "mcp__obsidian-second-brain__search"
            "mcp__obsidian-second-brain__query_notes"
            "mcp__obsidian-second-brain__read_note"
            "mcp__obsidian-second-brain__list_notes"
            "mcp__obsidian-second-brain__list_tags"
            "mcp__obsidian-second-brain__outline_note"
            "mcp__obsidian-second-brain__get_backlinks"
            "mcp__obsidian-second-brain__get_links"
            "mcp__obsidian-second-brain__append_note"
            "mcp__obsidian-second-brain__get_periodic_note"
            "mcp__obsidian-second-brain__append_periodic_note"

            "mcp__git__git_status"
            "mcp__git__git_diff"
            "mcp__git__git_diff_staged"
            "mcp__git__git_diff_unstaged"
            "mcp__git__git_log"
            "mcp__git__git_show"
            "mcp__git__git_branch"

            "mcp__filesystem__directory_tree"
            "mcp__filesystem__get_file_info"
            "mcp__filesystem__list_allowed_directories"
            "mcp__filesystem__list_directory"
            "mcp__filesystem__list_directory_with_sizes"
            "mcp__filesystem__read_file"
            "mcp__filesystem__read_media_file"
            "mcp__filesystem__read_multiple_files"
            "mcp__filesystem__read_text_file"
            "mcp__filesystem__search_files"

            "mcp__github__get_commit"
            "mcp__github__get_file_contents"
            "mcp__github__get_label"
            "mcp__github__get_latest_release"
            "mcp__github__get_me"
            "mcp__github__get_release_by_tag"
            "mcp__github__get_tag"
            "mcp__github__get_team_members"
            "mcp__github__get_teams"
            "mcp__github__issue_read"
            "mcp__github__list_branches"
            "mcp__github__list_commits"
            "mcp__github__list_issue_fields"
            "mcp__github__list_issue_types"
            "mcp__github__list_issues"
            "mcp__github__list_pull_requests"
            "mcp__github__list_releases"
            "mcp__github__list_repository_collaborators"
            "mcp__github__list_tags"
            "mcp__github__pull_request_read"
            "mcp__github__search_code"
            "mcp__github__search_commits"
            "mcp__github__search_issues"
            "mcp__github__search_pull_requests"
            "mcp__github__search_repositories"
            "mcp__github__search_users"

            "mcp__playwright__browser_snapshot"
            "mcp__playwright__browser_console_messages"
            "mcp__playwright__browser_network_requests"
            "mcp__playwright__browser_network_request"
            "mcp__playwright__browser_take_screenshot"
            "mcp__playwright__browser_find"
            "mcp__playwright__browser_wait_for"

            "mcp__fetch__fetch"

            # claude.ai personal connectors (account-level, not part of mcp.nix) --
            # read-only subset only. Send/create/update/delete/respond tools stay
            # excluded and keep prompting.
            "mcp__claude_ai_Anthropic_Economic_Index__*"
            "mcp__claude_ai_Context7__*"

            "mcp__claude_ai_Gmail__get_message"
            "mcp__claude_ai_Gmail__get_thread"
            "mcp__claude_ai_Gmail__list_drafts"
            "mcp__claude_ai_Gmail__list_labels"
            "mcp__claude_ai_Gmail__search_threads"

            "mcp__claude_ai_Google_Calendar__get_event"
            "mcp__claude_ai_Google_Calendar__list_calendars"
            "mcp__claude_ai_Google_Calendar__list_events"
            "mcp__claude_ai_Google_Calendar__search_events"
            "mcp__claude_ai_Google_Calendar__suggest_time"

            "mcp__claude_ai_Google_Drive__download_file_content"
            "mcp__claude_ai_Google_Drive__get_file_metadata"
            "mcp__claude_ai_Google_Drive__get_file_permissions"
            "mcp__claude_ai_Google_Drive__list_recent_files"
            "mcp__claude_ai_Google_Drive__read_file_content"
            "mcp__claude_ai_Google_Drive__search_files"

            "mcp__claude_ai_Notion__notion-fetch"
            "mcp__claude_ai_Notion__notion-download-attachment"
            "mcp__claude_ai_Notion__notion-get-async-task"
            "mcp__claude_ai_Notion__notion-get-comments"
            "mcp__claude_ai_Notion__notion-get-teams"
            "mcp__claude_ai_Notion__notion-get-users"
            "mcp__claude_ai_Notion__notion-query-data-sources"
            "mcp__claude_ai_Notion__notion-query-database-view"
            "mcp__claude_ai_Notion__notion-query-meeting-notes"
            "mcp__claude_ai_Notion__notion-search"

            "mcp__claude_ai_Excalidraw__read_checkpoint"
            "mcp__claude_ai_Excalidraw__read_me"
          ];
          deny = [
            "Read(~/.secrets/**)"
            "Read(~/.ssh/**)"
            "Read(~/.aws/**)"
            "Read(~/.gnupg/**)"
            "Read(**/*.env)"
            "Grep(~/.secrets/**)"
            "Grep(~/.ssh/**)"
            "Grep(~/.aws/**)"
            "Grep(~/.gnupg/**)"
            "Grep(**/*.env)"
            "Bash(*~/.secrets/*)"
            "Bash(*~/.ssh/*)"
            "Bash(*~/.aws/*)"
            "Bash(*~/.gnupg/*)"
            "Bash(*.env)"
            "Bash(*.env *)"
          ];
        };
        # mnemon hooks (scripts symlinked in via home.file above).
        hooks = {
          SessionStart = [{ hooks = [{ type = "command"; command = "${hooksDir}/prime.sh"; }]; }];
          Stop = [{ hooks = [{ type = "command"; command = "${hooksDir}/stop.sh"; }]; }];
          UserPromptSubmit = [{ hooks = [{ type = "command"; command = "${hooksDir}/user_prompt.sh"; }]; }];
          PostToolUse = [{ matcher = "Edit|Write"; hooks = [{ type = "command"; command = "${claudeHooksDir}/validate-config.sh"; }]; }];
        };
      });
      # MCP servers must be in ~/.claude.json (not settings.json)
      # Server list, packages, and secrets wiring are declared in ./mcp.nix
      claudeMcpFile = import ./mcp.nix { inherit pkgs; };
    in
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "$HOME/.claude"

      # mnemon's hooks, prompt, and skill are installed declaratively via
      # home.file (see the mnemon entries above); the data store self-initialises
      # on first use, so no `mnemon setup` is needed here.

      # Merge Nix-managed settings (permissions + mnemon hooks) into settings.json
      if [ -f "$HOME/.claude/settings.json" ]; then
        ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$HOME/.claude/settings.json" ${claudeSettingsFile} > "$HOME/.claude/settings.json.tmp"
        mv "$HOME/.claude/settings.json.tmp" "$HOME/.claude/settings.json"
      else
        cp ${claudeSettingsFile} "$HOME/.claude/settings.json"
      fi
      chmod 644 "$HOME/.claude/settings.json"

      if [ -f "$HOME/.claude.json" ]; then
        # jq's `*` deep-merges nested objects, so per-server fields removed
        # from mcp.nix (e.g. a stale `args` from before a wrapper existed)
        # would otherwise survive forever in mcpServers.<name>. Force
        # mcpServers to be wholesale-replaced by the new config instead of
        # deep-merged, while still deep-merging everything else (OAuth
        # tokens, project state, etc. that Nix doesn't manage).
        ${pkgs.jq}/bin/jq -s '.[0] as $old | .[1] as $new | ($old * $new) | .mcpServers = $new.mcpServers' "$HOME/.claude.json" ${claudeMcpFile} > "$HOME/.claude.json.tmp"
        mv "$HOME/.claude.json.tmp" "$HOME/.claude.json"
      else
        cp ${claudeMcpFile} "$HOME/.claude.json"
      fi
      chmod 644 "$HOME/.claude.json"
    '';

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
