"""Consistent hot snapshots of the engram and mnemon SQLite databases.

engram runs in WAL mode and routinely holds several MB of committed rows in
engram.db-wal. Copying engram.db with `cp` would silently lose them, so this
uses SQLite's online backup API, then converts each copy to DELETE journal
mode so the archived file is readable without -wal/-shm siblings.

Fails loudly (exit 1) if any copy is corrupt or if any table's row count does
not match the live database.
"""

import glob
import os
import sqlite3
import sys


def targets(home, work):
    out = [
        (
            "engram",
            f"{home}/.engram/engram.db",
            f"{work}/databases/engram/engram.db",
        )
    ]
    for db in sorted(glob.glob(f"{home}/.mnemon/data/*/mnemon.db")):
        store = os.path.basename(os.path.dirname(db))
        out.append((store, db, f"{work}/databases/mnemon/{store}/mnemon.db"))
    return out


def main():
    home, work = sys.argv[1], sys.argv[2]
    failures = []

    for name, src, dst in targets(home, work):
        os.makedirs(os.path.dirname(dst), exist_ok=True)

        live = sqlite3.connect(src)
        copy = sqlite3.connect(dst)
        live.backup(copy)
        copy.commit()
        # Fold the WAL into the main file; no sidecar files needed.
        copy.execute("pragma journal_mode=delete")
        live.close()
        copy.close()

        snap = sqlite3.connect(f"file:{dst}?mode=ro", uri=True)
        if snap.execute("pragma integrity_check").fetchone()[0] != "ok":
            failures.append(f"{name}: integrity_check failed")

        tables = [
            row[0]
            for row in snap.execute(
                "select name from sqlite_master "
                "where type='table' and name not like 'sqlite_%'"
            )
        ]
        source = sqlite3.connect(f"file:{src}?mode=ro", uri=True)
        for table in tables:
            live_rows = source.execute(f'select count(*) from "{table}"').fetchone()[0]
            snap_rows = snap.execute(f'select count(*) from "{table}"').fetchone()[0]
            if live_rows != snap_rows:
                failures.append(
                    f"{name}.{table}: live {live_rows} rows, snapshot {snap_rows} rows"
                )
        source.close()
        snap.close()

        print(f"  {name}: {os.path.getsize(dst)} bytes, {len(tables)} tables verified")

    if failures:
        print("snapshot verification FAILED:", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
