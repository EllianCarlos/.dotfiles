---
name: laya
description: Use when a task needs a fast yes/no answer, multiple-choice classification, or a 0-1 confidence score from unstructured text -- intent detection, triage, moderation, guardrails, routing, spam/phishing checks -- instead of spending a full LLM call on it.
---

# laya

## Overview

laya is a local, non-autoregressive decision model running on this machine as an
HTTP server (`nixos/modules/services/laya.nix`, port 11436, loopback-only). It
answers typed yes/no, multiple-choice, and 0-1 score questions about a piece of
text in a single forward pass -- tens of milliseconds, not a generation-speed LLM
call. Use it for the "System 1" classification work that precedes or guards an
LLM call, not for anything that requires generating text or reasoning through
steps.

Manage the service with `laya-start` / `laya-stop` / `laya-status` / `laya-setup`
(first run, waits for model download + load).

## When to Use

- Routing a request to the right downstream handler (agent, model, team) before
  spending a real LLM call on it
- Triage: support tickets, inbound email, moderation queues
- LLM input/output guardrails: jailbreak/prompt-injection/sensitive-data checks
- Any place you'd otherwise ask an LLM "is X true about this text, yes or no"

Not for: generating text, multi-step reasoning, anything needing more than a
label/score back.

## Quick Reference

```bash
curl -s http://127.0.0.1:11436/health
# {"status": "ok", "loaded": ["english", "multilingual", "typed-decisions"]}

curl -s -X POST http://127.0.0.1:11436/predict -H 'content-type: application/json' -d '{
  "state": {"message": "I was charged twice this month, please fix it"},
  "questions": {
    "intent": {
      "type": "choice",
      "instructions": "What does the customer want in `message`?",
      "criteria": {"refund": "money returned or a duplicate charge reversed", "other": "none of the above fits"}
    },
    "is_urgent": {"type": "noul", "instructions": "Does `message` communicate time pressure?"},
    "frustration": {
      "type": "score",
      "instructions": "How frustrated does the customer sound?",
      "criteria": ["calm", "concerned", "annoyed", "very angry"]
    }
  }
}'
```

`POST /route` runs only the language/checkpoint routing decision, no inference
(useful for debugging which checkpoint a request would hit).

## Request Shape

- `state`: a string, or a dict/list whose fields your `instructions` reference
  (e.g. `message`, `body`, `prompt` -- backtick the field name in the instruction
  text so laya knows what to read).
- `questions`: a dict of `question_id -> question`. Each question has:
  - `type`: `"choice"` (pick one of `criteria`), `"score"` (ordinal position in a
    `criteria` list), or `"noul"` (calibrated 0.0-1.0 probability, no criteria
    needed)
  - `instructions`: the yes/no or classification question, referencing a field
    in `state` with backticks
  - `criteria`: required for `choice`/`score` -- a dict (`choice`, label ->
    description) or ordered list (`score`, low -> high)
- Optional: `model` (`"english"` / `"multilingual"` / `"typed-decisions"`),
  `task`, `lang` -- omit all three to let laya auto-route by detected language.

Five ready-made question sets exist upstream if you don't want to write your
own: `triage_questions`, `email_questions`, `guard_questions`,
`moderation_questions`, `router_questions` (see laya's `laya/presets.py` on
GitHub for the exact field lists each one expects in `state`).

## Common Mistakes

- Asking an open-ended question ("summarize this") -- laya only answers
  typed choice/score/noul questions, it does not generate free text.
- Forgetting to start the service first (`laya-start`) -- `/health` returning
  connection-refused means it's stopped, not that something's broken.
- Referencing a `state` field in `instructions` that doesn't exist in the
  `state` payload you sent -- laya reads exactly what you give it.
