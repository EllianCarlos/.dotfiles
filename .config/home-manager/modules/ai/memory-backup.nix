# Daily, self-contained backup of the two agent memory stores:
#
#   engram  ~/.engram/engram.db                    (project memory)
#   mnemon  ~/.mnemon/data/<store>/mnemon.db       (global memory + config)
#
# Destination is /mnt/outros/memory-backup, which lives on the *other*
# physical disk (sda) so a root-disk repartition/reinstall cannot take it out.
# Only the current copy is kept: each run replaces the previous one.
#
# Two things this deliberately does NOT do naively:
#
#   1. It never `cp`s a database file. engram runs in WAL mode and routinely
#      holds several MB of committed-but-uncheckpointed data in engram.db-wal;
#      copying engram.db alone silently loses those rows. snapshot.py uses
#      SQLite's online backup API instead, then switches the copy to DELETE
#      journal mode so the archived file is self-contained.
#
#   2. It never deletes the previous backup until the new one has been built
#      AND verified (integrity_check + per-table row counts). A failed run
#      leaves the last good copy untouched.
{ pkgs, ... }:
let
  custom = import ../../pkgs { inherit pkgs; };

  backupRoot = "/mnt/outros/memory-backup";

  memory-backup = pkgs.writeShellApplication {
    name = "memory-backup";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnutar
      pkgs.gzip
      pkgs.python3
      pkgs.util-linux
      custom.engram
      custom.mnemon
    ];
    text = ''
      set -euo pipefail

      root=${backupRoot}
      home_dir="$HOME"

      if ! mountpoint -q /mnt/outros; then
        printf '%s\n' \
          "error: /mnt/outros is not mounted;" \
          "refusing to write a backup onto the root filesystem" >&2
        exit 1
      fi

      mkdir -p "$root"
      work="$(mktemp -d "$root/.incoming.XXXXXX")"

      cleanup() {
        if [ -d "$work" ]; then
          rm -rf "$work"
        fi
      }
      trap cleanup EXIT

      mkdir -p "$work/databases/engram" "$work/databases/mnemon" \
        "$work/exports" "$work/logs" "$work/config"

      printf '%s\n' "== snapshotting databases =="
      python3 ${../../files/memory-backup/snapshot.py} "$home_dir" "$work"

      # Portable logical dump: survives an engram version jump that a raw
      # database file might not (`engram import` reads this back).
      printf '%s\n' "== exporting engram json =="
      engram export "$work/exports/engram-export.json" >/dev/null

      # Human-readable graph snapshots; cosmetic, so a failure is not fatal.
      for store_dir in "$work"/databases/mnemon/*/; do
        [ -d "$store_dir" ] || continue
        store="$(basename "$store_dir")"
        if ! mnemon --store "$store" viz --format html \
          -o "$work/exports/mnemon-graph-$store.html" >/dev/null 2>&1; then
          printf 'warn: could not render mnemon graph for store %s\n' "$store" >&2
        fi
      done

      # Store bookkeeping files (best effort -- they may not exist yet).
      if [ -f "$home_dir/.mnemon/active" ]; then
        cp "$home_dir/.mnemon/active" "$work/config/mnemon-active-store"
      fi
      if [ -f "$home_dir/.mnemon/metrics.log" ]; then
        cp "$home_dir/.mnemon/metrics.log" "$work/logs/mnemon-metrics.log"
      fi
      if [ -d "$home_dir/.mnemon/prompt" ]; then
        cp -a "$home_dir/.mnemon/prompt" "$work/config/mnemon-prompt"
      fi

      printf '%s\n' "== writing manifest =="
      python3 ${../../files/memory-backup/manifest.py} "$work"

      printf '%s\n' "== checksumming =="
      (
        cd "$work"
        find . -type f ! -name SHA256SUMS ! -name '.SHA256SUMS.tmp' -print0 \
          | sort -z \
          | xargs -0 sha256sum >.SHA256SUMS.tmp
        mv .SHA256SUMS.tmp SHA256SUMS
      )

      # Swap: the previous copy only disappears once the new one is complete.
      printf '%s\n' "== installing new backup =="
      if [ -d "$root/current" ]; then
        mv "$root/current" "$root/current.old"
      fi
      mv "$work" "$root/current"
      rm -rf "$root/current.old"

      tar -czf "$root/.memory-backup.tar.gz.new" -C "$root" current
      tar -tzf "$root/.memory-backup.tar.gz.new" >/dev/null
      gzip -t "$root/.memory-backup.tar.gz.new"
      mv -f "$root/.memory-backup.tar.gz.new" "$root/memory-backup.tar.gz"

      printf 'backup complete: %s (%s), archive %s\n' \
        "$root/current" \
        "$(du -sh "$root/current" | cut -f1)" \
        "$(du -h "$root/memory-backup.tar.gz" | cut -f1)"
    '';
  };
in
{
  home.packages = [ memory-backup ];

  systemd.user.services.memory-backup = {
    Unit.Description = "Snapshot engram and mnemon memory stores to /mnt/outros/memory-backup";
    Service = {
      Type = "oneshot";
      ExecStart = "${memory-backup}/bin/memory-backup";
      # The stores are a few MB; anything near this means something hung.
      TimeoutStartSec = "10min";
    };
  };

  systemd.user.timers.memory-backup = {
    Unit.Description = "Daily memory backup (engram + mnemon)";
    Timer = {
      OnCalendar = "*-*-* 13:00:00";
      # Runs at next login if the machine was off/asleep at 13:00.
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
