{ pkgs, ... }:
let
  # Interpolating a pure-data file with no free variables copies it into
  # the store at build time -- the script gets a fixed, immutable path to
  # `nix eval` regardless of cwd or whether ~/Projects/.dotfiles still
  # exists/is checked out on this machine.
  pinsFile = ./pins.nix;

  check-nix-pins = pkgs.writeShellApplication {
    name = "check-nix-pins";
    runtimeInputs = [ pkgs.nix pkgs.git pkgs.jq pkgs.libnotify pkgs.coreutils pkgs.claude-code pkgs.gnugrep ];
    text = ''
      pins_file=${pinsFile}
      repo_dir="$HOME/Projects/.dotfiles"
      stale=0
      unknown=0
      stale_list=""

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
          stale_list="$stale_list- $name ($owner/$repo): pinned=$rev upstream=$upstream
"
        fi
      done < <(nix eval --json --file "$pins_file" \
        | jq -r 'to_entries[] | select(.value.frozen != true) | [.key, .value.owner, .value.repo, .value.rev] | @tsv')

      if [ "$stale" -eq 1 ]; then
        if [ ! -d "$repo_dir/.git" ]; then
          echo "warn: $repo_dir is not a checkout -- skipping automated fix" >&2
          notify-send --urgency=normal "Nix pins out of date" \
            "Stale pins found but $repo_dir is missing -- run 'check-nix-pins' for details."
          exit 1
        fi

        prompt="Pinned upstream commits in $pins_file are behind. Bring them current:

$stale_list
For each pin above:
1. Update its rev in $pins_file to the new upstream commit.
2. Fetch the new tarball (as skills.nix/home.nix/mcp.nix would) and confirm
   every subdir/path those files reference from it still exists. If a bump
   breaks a downstream reference and there is no clean one-line fix, do not
   force it -- leave that single pin at its last-good rev, add
   \`frozen = true;\` to its entry so check-nix-pins stops flagging it, and
   say why in your summary.
3. Validate: run \`nix-instantiate --parse\` on every .nix file you changed,
   then run \`nix-build '<nixpkgs/nixos>' --attr config.system.build.toplevel --no-out-link\`
   to confirm the full system still evaluates and builds.
4. Do not run sudo, nixos-rebuild, or anything that touches the running
   system. Do not run git add, git commit, git push, git reset, or git
   clean -- leave your edits as uncommitted working-tree changes in
   $repo_dir for the user to review and commit themselves.

End your reply with exactly one line starting with 'SUMMARY:' (under 200
chars) stating what you changed and whether it built cleanly."

        out_file=$(mktemp)
        claude_exit=0
        if ! (cd "$repo_dir" && timeout 25m claude -p "$prompt" \
          --permission-mode acceptEdits \
          --allowedTools "Read Write Edit Grep Glob Bash(git ls-remote:*) Bash(git clone:*) Bash(git log:*) Bash(git status:*) Bash(git diff:*) Bash(git checkout:*) Bash(nix-instantiate:*) Bash(nix-build:*) Bash(nix eval:*) Bash(nix search:*) Bash(jq:*) Bash(cat:*) Bash(ls:*) Bash(mkdir:*) Bash(rm:*)" \
          --disallowedTools "Bash(sudo:*) Bash(nixos-rebuild:*) Bash(git commit:*) Bash(git push:*) Bash(git add:*) Bash(git reset:*) Bash(git clean:*)" \
          --output-format text > "$out_file" 2>&1); then
          claude_exit=$?
        fi

        summary=$(grep -m1 '^SUMMARY:' "$out_file" || true)
        if [ "$claude_exit" -ne 0 ] || [ -z "$summary" ]; then
          notify-send --urgency=critical "Nix pins: auto-fix failed" \
            "check-nix-pins tried to draft a fix and hit an error (exit $claude_exit). See $out_file."
        else
          notify-send --urgency=normal "Nix pins: fix drafted, review needed" \
            "$summary  Run 'git -C $repo_dir diff' to review, then rebuild yourself."
        fi

        cat "$out_file"
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
    Unit.Description = "Check pinned Nix fetches (mcp.nix/home.nix/skills.nix) against upstream HEAD, and draft a fix via headless Claude when stale";
    Service = {
      Type = "oneshot";
      ExecStart = "${check-nix-pins}/bin/check-nix-pins";
      # The script's own `timeout 25m claude ...` bounds the Claude call;
      # this gives it room to run without systemd's default ~90s
      # TimeoutStartSec killing the unit first.
      TimeoutStartSec = "30min";
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
