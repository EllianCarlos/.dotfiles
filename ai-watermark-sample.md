---
title: "AI watermark test fixture"
generator: "Claude (Anthropic)"
ai-generated: true
content-credentials: "c2pa-manifest-placeholder-0000"
---

> Note: An AI model (Claude, by Anthropic) wrote this file. It is a test
> fixture for the `remove-ai-marks` skill, not real content.

## Sample text

This paragraph holds hidden marks.​ Some marks sit between words,‌
some sit before a word,‍ and some use a word joiner.⁠ One line below
starts with a byte-order mark.

﻿This line starts with a BOM character. The line also has a non-breaking
space here and an ideographic space　here.

This span uses a bidi override to change display order: ‮DESREVER‬ —
and this word carries an invisible variation selector️ mark.

This word carries a hidden tag-character run: X󠀁󠀂󠀃Y.

## Hook test

This line checks whether the fixed `format-on-write.sh` guard now runs the
clean step on save.

## Fixture map

- **Visible marker** — the blockquote note above.
- **Container metadata** — YAML frontmatter keys: `generator`, `ai-generated`, `content-credentials`.
- **Invisible Unicode (Layer A)**:
  - ZWSP, ZWNJ, ZWJ, word joiner — `zwj_family`
  - BOM at line start — `zwj_family`
  - NBSP, ideographic space — `space`
  - RLO / PDF bidi override — `bidi`
  - Variation selector (VS16) — `variation_selector`
  - Tag characters (U+E0001–E0003 range) — `tag_chars`

Run against this file:

```bash
python3 "$SCRIPTS/inspect_text.py" ai-watermark-sample.md
python3 "$SCRIPTS/clean_text.py" ai-watermark-sample.md -o ai-watermark-sample.cleaned.md --stats
```
