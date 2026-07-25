{ pkgs, ... }:
let
  # Interpolating a pure-data file with no free variables copies it into
  # the store at build time -- the script gets a fixed, immutable path to
  # `nix eval` regardless of cwd or whether ~/Projects/.dotfiles still
  # exists/is checked out on this machine.
  pinsFile = ./pins.nix;

  check-nix-pins = pkgs.writeShellApplication {
    name = "check-nix-pins";
    runtimeInputs = [ pkgs.nix pkgs.git pkgs.jq pkgs.libnotify pkgs.coreutils ];
    text = ''
      pins_file=${pinsFile}
      stale=0
      unknown=0

      while IFS=$'\t' read -r name owner repo rev; do
        upstream=""
        if ! upstream=$(timeout 15s git ls-remote --exit-code "https://github.com/$owner/$repo.git" HEAD 2>/dev/null | cut -f1); then
          echo "warn: could not reach https://github.com/$owner/$repo.git (offline or GitHub unreachable) -- skipping $name" >&2
          unknown=1
          continue
        fi

        if [ "$rev" = "$upstream" ]; then
          echo "OK     $name  $rev"
        else
          echo "STALE  $name  pinned=$rev  upstream=$upstream"
          stale=1
        fi
      done < <(nix eval --json --file "$pins_file" \
        | jq -r 'to_entries[] | [.key, .value.owner, .value.repo, .value.rev] | @tsv')

      if [ "$stale" -eq 1 ]; then
        notify-send --urgency=normal "Nix pins out of date" \
          "One or more pinned dependencies in home-manager (mcp.nix/home.nix/skills.nix) have a newer upstream commit. Run 'check-nix-pins' for details."
        exit 1
      fi

      if [ "$unknown" -eq 1 ]; then
        echo "note: some pins could not be checked (see warnings above); not treated as stale." >&2
        exit 2
      fi

      echo "all pins current."
      exit 0
    '';
  };
in
{
  home.packages = [ check-nix-pins ];

  systemd.user.services.check-nix-pins = {
    Unit.Description = "Check pinned Nix fetches (mcp.nix/home.nix/skills.nix) against upstream HEAD";
    Service = {
      Type = "oneshot";
      ExecStart = "${check-nix-pins}/bin/check-nix-pins";
      # "stale" (1) and "couldn't check" (2) are normal outcomes of this
      # check, not service crashes -- don't let them show up in
      # `systemctl --user --failed` / the journal at error severity.
      SuccessExitStatus = [ 1 2 ];
    };
  };

  systemd.user.timers.check-nix-pins = {
    Unit.Description = "Weekly check of pinned Nix fetches against upstream HEAD";
    Timer = {
      OnCalendar = "weekly";
      Persistent = true; # catches up immediately at next login/boot if the machine was off when the timer would have fired
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
