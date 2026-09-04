#!/usr/bin/env bash
# rag-watch -- re-run rag-reindex whenever ~/rag/sources changes.
#
# Recursive inotify watch with a debounce, so a burst of file events (e.g. a
# whole folder of PDFs symlinked in at once) collapses into a single reindex.
# A 5-minute timeout re-arms the watch as a safety net even with no events.
set -euo pipefail

SOURCES="${HOME}/rag/sources"
mkdir -p "${SOURCES}"

echo "[rag-watch] watching ${SOURCES} for changes" >&2
while true; do
  # Block until something changes (or the timeout fires as a periodic re-arm).
  inotifywait -r -q -t 300 \
    -e modify,create,delete,move,close_write \
    "${SOURCES}" >/dev/null 2>&1 || true
  # Debounce: let a burst of events settle before reindexing.
  sleep 10
  if ! rag-reindex; then
    echo "[rag-watch] reindex failed; will retry on next change" >&2
  fi
done
