{
  config,
  lib,
  pkgs,
  ...
}:
let
  ai-commit = pkgs.callPackage ../../pkgs/ai-commit { };
in
{
  # programs.zsh.autosuggestion.strategy is an enum of the built-in strategies,
  # so the custom one is prepended here instead. home-manager emits its own
  # ZSH_AUTOSUGGEST_STRATEGY right after sourcing zsh-autosuggestions at
  # mkOrder 700; 710 runs after it and keeps whatever built-ins are configured.
  programs.zsh.initContent = lib.mkMerge [
    (lib.mkOrder 710 ''
      ZSH_AUTOSUGGEST_STRATEGY=(ai_commit ${lib.concatStringsSep " " config.programs.zsh.autosuggestion.strategy})
    '')
    ''
      _zsh_autosuggest_strategy_ai_commit() {
        emulate -L zsh
        setopt extended_glob
        typeset -g suggestion
        [[ "$1" == git\ commit* ]] || return
        local top
        top="$(git rev-parse --show-toplevel 2>/dev/null)" || return
        local msg
        msg="$(${ai-commit}/bin/ai-commit message --cached)" || {
          # Cache miss: infer once in the background, guarded by a lock in the binary.
          ${pkgs.util-linux}/bin/setsid -f ${ai-commit}/bin/ai-commit warm </dev/null >/dev/null 2>&1
          return
        }
        [[ "$1" =~ '^(git commit.* -[a-zA-Z]*m ?)(["'"'"'])(.*)$' ]] || return
        local q="$match[2]" typed="$match[3]" subject body full
        subject="''${msg%%$'\n'*}"
        body=""
        [[ "$msg" == *$'\n\n'* ]] && body="''${msg#*$'\n\n'}"
        if [[ $q == '"' ]]; then
          subject="''${subject//(#m)[\\\"\$\`]/\\$MATCH}"
          body="''${body//(#m)[\\\"\$\`]/\\$MATCH}"
        else
          subject="''${subject//\'/\'\\\'\'}"
          body="''${body//\'/\'\\\'\'}"
        fi
        full="$subject$q"
        [[ -n "$body" ]] && full+=" -m $q$body$q"
        [[ "$full" == "$typed"* ]] || return
        suggestion="$1''${full#$typed}"
      }
    ''
  ];
}
