"""Write MANIFEST.md describing the memory backup just taken."""

import datetime
import json
import os
import sqlite3
import sys

ENGRAM_TABLES = ["observations", "sessions", "user_prompts", "memory_relations"]
MNEMON_TABLES = ["insights", "edges", "oplog"]


def counts(db, tables):
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    try:
        return {t: con.execute(f'select count(*) from "{t}"').fetchone()[0] for t in tables}
    finally:
        con.close()


def main():
    work = sys.argv[1]

    engram = counts(f"{work}/databases/engram/engram.db", ENGRAM_TABLES)

    stores = {}
    store_dir = f"{work}/databases/mnemon"
    for store in sorted(os.listdir(store_dir)):
        db = f"{store_dir}/{store}/mnemon.db"
        if os.path.exists(db):
            stores[store] = counts(db, MNEMON_TABLES)

    export = json.load(open(f"{work}/exports/engram-export.json"))

    rows = "\n".join(
        f"| mnemon store `{name}` | `~/.mnemon/data/{name}/mnemon.db` "
        f"| {c['insights']} insights, {c['edges']} edges, {c['oplog']} oplog entries |"
        for name, c in stores.items()
    )

    when = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")

    manifest = f"""# Memory backup

Generated automatically by `memory-backup.service` (daily systemd user timer).
Last run: {when}.

This directory is replaced on every run -- there is exactly one current copy.
If a run fails its own checks, the previous copy is left in place untouched.

## What is here

| Store | Location on live system | Contents |
|---|---|---|
| engram (project memory) | `~/.engram/engram.db` | {engram['observations']} observations, {engram['sessions']} sessions, {engram['user_prompts']} prompts, {engram['memory_relations']} conflict relations |
{rows}

`exports/engram-export.json` is a portable logical dump
({len(export['observations'])} observations, {len(export['sessions'])} sessions),
independent of the SQLite file format.

`exports/mnemon-graph-*.html` are human-readable graph views.

## Restore on a new system

Stop any running engram server / agent session first, then:

```bash
mkdir -p ~/.engram ~/.mnemon/data
cp databases/engram/engram.db ~/.engram/engram.db
for d in databases/mnemon/*/; do
  store="$(basename "$d")"
  mkdir -p ~/.mnemon/data/"$store"
  cp "$d/mnemon.db" ~/.mnemon/data/"$store"/mnemon.db
done
cp config/mnemon-active-store ~/.mnemon/active
cp logs/mnemon-metrics.log ~/.mnemon/metrics.log 2>/dev/null || true

engram stats
mnemon status
```

Fallback if a future engram version cannot open the raw database:
`engram import exports/engram-export.json`

## Integrity

* Every snapshot passed `PRAGMA integrity_check` at backup time.
* Every table's row count was compared against the live database.
* Snapshots come from SQLite's online backup API, so un-checkpointed
  `engram.db-wal` content is included; each copy is then switched to DELETE
  journal mode so it needs no `-wal`/`-shm` siblings.
* Checksums of all files are in `SHA256SUMS`.

This copy still lives on the same physical machine. Copy
`memory-backup.tar.gz` to external media before repartitioning or reinstalling.
"""

    with open(f"{work}/MANIFEST.md", "w") as handle:
        handle.write(manifest)
    print("  manifest written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
