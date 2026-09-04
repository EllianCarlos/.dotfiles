# Local RAG — SOP

Personal hybrid-RAG over your files, shared by Claude Code, Pi, and OpenCode.
Retrieval is local (agent-rag-mcp = ChromaDB + Ollama embeddings); generation
is your cloud LLM. All three agents call one MCP server against one DB.

## Layout

    ~/rag/
      sources/     <- symlink your real files here (PDF, PPTX, TeX, MD, code)
      corpus/      <- DERIVED Markdown/text (regenerated; do not edit)
      chroma_db/   <- ChromaDB vector store (agent-rag-mcp)
      config.yaml  <- agent-rag-mcp config (managed by Home Manager)
      ingest.py    <- headless ingest client (managed by Home Manager)

`sources/` is yours; `corpus/` and `chroma_db/` are regenerable.

## One-time setup

1. Pull the embedding model (must match `config.yaml`):

       ollama pull qwen3-embedding:0.6b

2. Put content in: symlink files/folders into `~/rag/sources`, e.g.

       ln -s ~/Projects/mestrado-space/papers ~/rag/sources/papers

3. Build the index:

       rag-reindex

4. Restart your agent (Claude/Pi/OpenCode) so it connects to the `rag` MCP
   server, then confirm: in Claude, `/mcp` shows `rag` connected; ask it to
   `rag_search` something you indexed.

## Keeping it fresh

- **Manual:** `rag-reindex` (convert changed sources + re-ingest).
- **Automatic:** the `rag-watch` user service watches `~/rag/sources` and
  reindexes on change (debounced).

      systemctl --user status rag-watch     # is it running?
      systemctl --user restart rag-watch    # restart it
      journalctl --user -u rag-watch -f     # follow its logs

Re-indexing updates the DB; a **running** MCP client caches its connection, so
after a big reindex, reconnect the client to be safe (`/mcp` reconnect).

## Conversion rules

- Markdown / text / source code -> copied through unchanged.
- PDF / PPTX / DOCX / XLSX -> `markitdown` -> Markdown.
- LaTeX `.tex` -> `pandoc` -> Markdown.
- Other extensions are skipped. (For higher-fidelity academic PDFs with math
  and tables, swap `markitdown` for `marker` in `files/rag/reindex.sh`.)

## Changing the embedding model

Embedding dimension is fixed at index time. To switch models: edit
`config.yaml`, then rebuild from scratch:

    rm -rf ~/rag/chroma_db && rag-reindex

## First-run verification (points I could not test off your machine)

1. **config.yaml pickup** — agent-rag-mcp reads `config.yaml` from its CWD; the
   `rag-mcp` launcher `cd`s to `~/rag` first. If `rag_search` ignores your
   Ollama model, run `rag-mcp` by hand in `~/rag` and check the startup log.
2. **rag_ingest argument names** — `ingest.py` introspects the tool schema and
   maps the corpus path automatically. If `rag-reindex` prints
   "could not map a corpus-path argument", it also prints the real schema —
   set the right key in `files/rag/ingest.py` (`PATH_KEYS`).
3. **Pi MCP config** — Pi's MCP registration shape is wired best-effort under
   `mcpServers.rag` in `~/.pi/agent/settings.json`. If Pi does not surface the
   tools, confirm Pi's expected MCP key (it uses `pi-mcp-adapter`).

## Troubleshooting

- `rag` shows `disconnected`: run `rag-mcp` directly in `~/rag` to see the
  stderr startup error (missing config, Ollama unreachable, model not pulled).
- Ingest ingests nothing: check `journalctl --user -u rag-watch` or run
  `rag-reindex` in a terminal and read the `[rag-ingest]` line.
