#!/usr/bin/env bash
# rag-reindex -- convert ~/rag/sources into a clean Markdown/text corpus, then
# ingest it into the local agent-rag-mcp knowledge base.
#
# Conversion keeps agent-rag-mcp fed with text it can chunk regardless of the
# original format:
#   - Markdown / text / source code -> copied through unchanged
#   - PDF / PPTX / DOCX / XLSX       -> markitdown -> Markdown
#   - LaTeX (.tex)                   -> pandoc -> Markdown (GitHub flavored)
# Anything else is skipped. Symlinks under sources/ are followed (find -L), so
# you can symlink real files into ~/rag/sources without copying them.
set -euo pipefail

SOURCES="${HOME}/rag/sources"
CORPUS="${HOME}/rag/corpus"
COLLECTION="${RAG_COLLECTION:-pessoal}"

mkdir -p "${CORPUS}"

if [ ! -d "${SOURCES}" ]; then
  echo "[rag-reindex] no sources dir at ${SOURCES}; nothing to do" >&2
  exit 0
fi

# 1) Convert / copy sources into the corpus.
while IFS= read -r -d '' src; do
  rel="${src#"${SOURCES}/"}"
  ext="${src##*.}"
  ext="${ext,,}"
  case "${ext}" in
    md | markdown | txt | rst | org | py | js | ts | tsx | jsx | rs | go | java | kt | c | h | cpp | hpp | cs | rb | php | sh | bash | zsh | nix | toml | yaml | yml | json | sql | lua | vim)
      dest="${CORPUS}/${rel}"
      mkdir -p "$(dirname "${dest}")"
      cp -f "${src}" "${dest}"
      ;;
    pdf | pptx | ppt | docx | doc | xlsx)
      dest="${CORPUS}/${rel}.md"
      mkdir -p "$(dirname "${dest}")"
      if ! uvx markitdown "${src}" >"${dest}" 2>/dev/null; then
        echo "[rag-reindex] markitdown failed, skipping: ${rel}" >&2
        rm -f "${dest}"
      fi
      ;;
    tex | latex)
      dest="${CORPUS}/${rel}.md"
      mkdir -p "$(dirname "${dest}")"
      if ! pandoc "${src}" -t gfm -o "${dest}" 2>/dev/null; then
        echo "[rag-reindex] pandoc failed, skipping: ${rel}" >&2
        rm -f "${dest}"
      fi
      ;;
    *)
      : # unsupported extension -- skip
      ;;
  esac
done < <(find -L "${SOURCES}" -type f -print0 2>/dev/null)

# 2) Ingest the corpus into agent-rag-mcp (headless, via a one-shot MCP call).
echo "[rag-reindex] conversion done; ingesting ${CORPUS} into collection '${COLLECTION}'" >&2
RAG_MCP_CMD="rag-mcp" uv run --with mcp python "${HOME}/rag/ingest.py" "${CORPUS}" "${COLLECTION}"
echo "[rag-reindex] done" >&2
