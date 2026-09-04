### Two memory stores (split by scope)

- **mnemon** — GLOBAL, cross-project knowledge: user preferences, decisions,
  identity, cross-cutting facts that should follow you into every repo.
- **engram** — PER-PROJECT working memory (MCP `mem_*`): bugfixes, architecture
  decisions, discoveries, conventions, and session handoffs scoped to the CURRENT
  repo.

Routing rule: a fact about the USER or spanning repos → mnemon. A fact about
THIS codebase/project → engram. Never store the same fact in both.

### Recall — automatic

Global mnemon memories are **auto-recalled every turn** by the UserPromptSubmit
hook and injected under `[mnemon:recall]`. You do NOT need to run `mnemon recall`
for general context — it is already in front of you.

Run `mnemon recall "<focused query>" --limit 5` manually only for a *targeted*
deep lookup the auto-recall missed (a specific past decision, entity, or file).
Craft a focused, keyword-rich query — do not pass the raw user prompt.

For project/codebase history, use engram instead (`mem_search`, `mem_context`).

**Before web search**: check the auto-recalled context first — stored context
sharpens queries.

### Remember — after responding

Run this decision tree after every substantive response.
**Bias toward storing**: when in doubt, store it. Low-importance memories are cheap; missing context is expensive.

**Step 1 — Does this exchange contain any of the following?**

Tier A (importance 4-5, always store):
- User directive — explicit preference, decision, correction, or "remember this"
- Reasoning conclusion — non-trivial judgment from multi-source synthesis
- Durable system/architectural fact discovered during this session
- User-specific context that no search engine can recover

Tier B (importance 2-3, store unless trivial):
- Casual preference revealed in passing ("I usually...", "I prefer...", "I don't like...")
- Topic the user is currently exploring or curious about
- Useful framing or analogy the user offered
- Background context about the user's projects, tools, or setup
- Interesting question the user raised, even if not fully resolved

Tier C (importance 1, store only if genuinely reusable):
- Conversational context that might help future sessions feel continuous
- Soft signal about communication style or mood

→ None of the above → STOP.

**Step 2 — Does a highly overlapping memory already exist?**
→ Yes, incremental new info → UPDATE (merge into existing)
→ Yes, but contradicts/supersedes → REPLACE
→ No significant overlap → CREATE

**Step 3 — Importance calibration**
Use the full 1-5 scale intentionally:
- 5: Cross-session core fact, architectural decision, strong user preference
- 4: Important context, significant finding, clear user preference
- 3: Useful background, project context, topic of interest
- 2: Passing mention, soft preference, conversational color
- 1: Ephemeral but potentially useful continuity

Aim for a rough distribution: ~20% at 4-5, ~50% at 2-3, ~30% at 1.
Avoid defaulting everything to 4-5 — that defeats the scoring system.

**Where to store**: global/user/cross-project facts → mnemon (this decision tree).
Facts scoped to the current repo/codebase → engram `mem_save` instead. The Stop
hook is a blocking gate: at end of turn it forces this evaluation, so make the
store decision deliberately rather than skipping it.
**What to store**: both conclusions AND context. Prefer storing a little too much over missing something useful.
**How to store**: delegate to a Task sub-agent (`subagent_type="general-purpose"`, `model="sonnet"`).
Only provide what to store — content, category, importance, entities, and create/update intent.
The sub-agent will read the mnemon skill and execute the correct commands itself.

Do NOT: write CLI commands or workflow steps in the sub-agent prompt (the sub-agent has access to the skill docs and will use the correct flags).
Do NOT run memory writes in the main conversation, or remember operational/public/git-tracked/transient info.
