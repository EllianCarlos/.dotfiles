---
name: mnemon
description: Persistent memory CLI for LLM agents. Store facts, recall past knowledge, link related memories, manage lifecycle.
---

# mnemon

## Workflow

1. **Remember**: `mnemon remember "<fact>" --cat <cat> --imp <1-5> --entities "e1,e2" --source agent`
   - Diff is built-in: duplicates skipped, conflicts auto-replaced.
   - Output includes `action` (added/updated/skipped), `semantic_candidates`, `causal_candidates`.
2. **Link** (evaluate candidates from step 1 — use judgment, not mechanical rules):
   - Review `causal_candidates`: does a genuine cause-effect relationship exist? `causal_signal` is regex-based and prone to false positives — only link if the memories are truly causally related.
   - Review `semantic_candidates`: are these memories meaningfully related? High `similarity` alone is not sufficient — skip candidates that share keywords but discuss unrelated topics.
   - Syntax: `mnemon link <id> <candidate> --type <causal|semantic> --weight <0-1> [--meta '<json>']`
3. **Recall**: `mnemon recall "<query>" --limit 10`

## Commands

```bash
mnemon remember "<fact>" --cat <cat> --imp <1-5> --entities "e1,e2" --source agent
mnemon link <id1> <id2> --type <type> --weight <0-1> [--meta '<json>']
mnemon recall "<query>" --limit 10
mnemon search "<query>" --limit 10
mnemon forget <id>
mnemon related <id> --edge causal
mnemon gc --threshold 0.4
mnemon gc --keep <id>
mnemon status
mnemon log
mnemon store list
mnemon store create <name>
mnemon store set <name>
mnemon store remove <name>
```

## Guardrails

- Never run `remember` or `link` in the main conversation — always delegate to a sub-agent.
- Do not store secrets, passwords, or tokens.
- Categories: `preference` · `decision` · `insight` · `fact` · `context`
- Edge types: `temporal` · `semantic` · `causal` · `entity`
- Max 8,000 chars per insight.
- Entities must be genuine named things: people, files, paths, repos, hosts, tools, orgs.
  Never emphasis words (NEVER, ONLY, ALWAYS), abbreviations (e.g., i.e.), or generic nouns
  pulled from the sentence just because they are capitalized.
- `--entities` does NOT override extraction — `mnemon` always runs its own auto-extraction
  on the content and merges it in, even with a clean `--entities` list (confirmed: the flag's
  own help text says "merged with auto-extraction"; no flag turns this off). Auto-extraction
  grabs capitalized tokens, so it re-adds words like NEVER/ONLY/LOCAL if the content itself
  is written in ALL-CAPS for emphasis. To actually keep entities clean, write emphasis in
  fact content as lowercase phrasing ("must never be pushed", not "must NEVER be pushed") —
  fixing the `--entities` list alone will not stop the noise.
