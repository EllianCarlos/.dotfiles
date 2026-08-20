#!/usr/bin/env bash
# mnemon Stop hook — memory reminder (suggestion mode, always-on).
# Non-blocking: outputs a reminder that the model sees but is not forced to act on.
# The model's CLAUDE.md instructions handle the actual memory evaluation.
# Fires on every stop, with no silence check -- a log audit on 2026-08-15
# showed 7 recall calls and 0 remember calls in one day, so the old
# suppress-if-already-mentioned regex was cut: it let the model talk past
# the reminder without ever running the remember sub-agent.

cat >/dev/null # drain stdin; the hook payload is not used

echo "[mnemon] STOP: before you end this turn, name AT LEAST one thing from this exchange worth a remember sub-agent -- a directive, a correction, a decision, or a durable fact. Do not end the turn silently."
