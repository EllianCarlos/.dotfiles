# zsh, oh-my-zsh, Powerlevel10k, and the shell aliases.
{ pkgs, ... }:
{
  home.file.".p10k.zsh".source = ../../files/zsh/p10k.zsh;

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;

    localVariables = {
      ZSH_DISABLE_COMPFIX = "true";
    };

    shellAliases = {
      # --- Files & editor ---------------------------------------------------
      la = "ls -la";
      ll = "ls -l";
      v = "nvim";

      # --- NixOS ------------------------------------------------------------
      # Mirror the local config into /etc/nixos (deleting files removed from
      # the repo, unlike a plain `cp`), then rebuild.
      update = "sudo rsync -a --delete ~/Projects/.dotfiles/nixos/ /etc/nixos/ && sudo nixos-rebuild switch";
      # Quick garbage collection
      gc = "nix-collect-garbage -d && sudo nix-collect-garbage -d";

      # --- System history (atop) --------------------------------------------
      # atopsar summaries read today's log automatically.
      atop-mem = "atopsar -m"; # memory + swap over time
      atop-swap = "atopsar -s"; # swap pressure
      atop-cpu = "atopsar -c"; # cpu utilisation
      atop-procs = "atopsar -G"; # top memory-consuming processes
      atop-cpuprocs = "atopsar -p"; # top cpu-consuming processes
      # Interactive replay. Inside atop: t/T step through samples, m sorts by
      # memory, c shows full command lines, q quits. For any other day:
      #   atop -r /var/log/atop/atop_20260807 -b 15:10
      atop-today = "atop -r /var/log/atop/atop_$(date +%Y%m%d)";
      atop-yday = "atop -r /var/log/atop/atop_$(date -d yesterday +%Y%m%d)";
      # What the kernel or earlyoom killed this boot
      oom-log = "journalctl -b | grep -iE 'oom|killed process|earlyoom'";

      # --- Audio ------------------------------------------------------------
      # Change default sink
      audio-headset = "audio-to alsa_output.usb-Logitech_G535_Wireless_Gaming_Headset-00.analog-stereo";
      audio-hdmi = "audio-to alsa_output.pci-0000_03_00.1.hdmi-stereo-extra1";
      audio-combine = "audio-to combine-sink";

      caffeinate = "systemd-inhibit --what=idle:sleep:handle-lid-switch --why='coding-through-the-phone' sleep infinity";

      # --- Ollama -------------------------------------------------------------
      # Stop frees the RAM/VRAM the loaded model holds; it does not auto-restart
      # until next boot or until you run ollama-start again.
      ollama-start = "sudo systemctl start ollama";
      ollama-stop = "sudo systemctl stop ollama";
      ollama-status = "systemctl status ollama";

    };

    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    # Merged into one initContent block, rather than split across
    # initContent/initExtra, because both options are deprecated-adjacent
    # (initExtra) or module-position-sensitive (initContent's merge order
    # with other modules' contributions), and a single string removes any
    # ambiguity about relative ordering.
    initContent = ''
      [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

      # gpg-agent picks the tty for pinentry-curses from GPG_TTY. Without
      # this, a shell started inside a nested terminal (neovim's
      # :terminal, tmux) keeps a stale tty from the parent shell, and any
      # gpg call (directly, or via `pass` below) hangs or corrupts that
      # other terminal instead of prompting where you can see it.
      export GPG_TTY="$(tty)"
      ${pkgs.gnupg}/bin/gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1

      # --- Antigravity CLI (agy): API-key auth, no interactive login -------
      export GEMINI_API_KEY="$(${pkgs.pass}/bin/pass show gemini 2>/dev/null)"
      # opencode's Google provider (ai-sdk) reads a different variable name
      # for the same key -- without this, opencode's google/* models fail
      # with AI_LoadAPIKeyError even though agy authenticates fine.
      export GOOGLE_GENERATIVE_AI_API_KEY="$GEMINI_API_KEY"

      audio-to() {
        pactl set-default-sink "$1"
        for i in $(pactl list short sink-inputs | cut -f1); do
          pactl move-sink-input "$i" "$1" 2>/dev/null
        done
      }

      if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
        source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
      fi
    '';

    oh-my-zsh = {
      enable = true;

      plugins = [
        "git"
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
}
