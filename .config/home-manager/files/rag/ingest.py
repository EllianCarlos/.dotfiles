#!/usr/bin/env python3
"""One-shot headless ingest for agent-rag-mcp.

agent-rag-mcp exposes ingestion only as the MCP tool ``rag_ingest`` (there is
no documented ingest CLI), so to reindex from systemd/cron we spawn the server
over stdio and call the tool ourselves.

The tool's exact argument names are NOT documented, so rather than hardcode a
guess we read its ``inputSchema`` at runtime and map our corpus directory and
collection onto the best-matching properties. If it cannot be mapped, we print
the real schema to stderr and exit non-zero so the failure is legible in the
journal instead of silently ingesting nothing.

Usage:  RAG_MCP_CMD=rag-mcp uv run --with mcp python ingest.py <corpus_dir> <collection>
"""
from __future__ import annotations

import asyncio
import os
import sys

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

CORPUS = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/rag/corpus")
COLLECTION = sys.argv[2] if len(sys.argv) > 2 else "pessoal"
SERVER_CMD = os.environ.get("RAG_MCP_CMD", "rag-mcp")

# Candidate property names, most-specific first, matched case-insensitively
# against rag_ingest's inputSchema.
PATH_KEYS = ("path", "directory", "dir", "source", "sources", "folder", "documents", "input")
COLL_KEYS = ("collection", "collection_name", "name")


def pick(properties: dict, candidates: tuple[str, ...]) -> str | None:
    lower = {k.lower(): k for k in properties}
    for cand in candidates:
        if cand in lower:
            return lower[cand]
    return None


async def main() -> int:
    params = StdioServerParameters(command=SERVER_CMD, args=[])
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            listing = await session.list_tools()
            ingest = next((t for t in listing.tools if t.name == "rag_ingest"), None)
            if ingest is None:
                names = [t.name for t in listing.tools]
                print(f"[rag-ingest] rag_ingest tool not found; tools={names}", file=sys.stderr)
                return 1

            schema = getattr(ingest, "inputSchema", None) or {}
            props = schema.get("properties", {})
            path_key = pick(props, PATH_KEYS)
            coll_key = pick(props, COLL_KEYS)
            if path_key is None:
                print(
                    "[rag-ingest] could not map a corpus-path argument onto rag_ingest; "
                    f"schema properties = {list(props)}",
                    file=sys.stderr,
                )
                return 2

            args: dict[str, str] = {path_key: CORPUS}
            if coll_key is not None:
                args[coll_key] = COLLECTION

            result = await session.call_tool("rag_ingest", args)
            if getattr(result, "isError", False):
                print(f"[rag-ingest] rag_ingest returned an error: {result.content}", file=sys.stderr)
                return 3
            print(
                f"[rag-ingest] ingested {CORPUS} into collection '{COLLECTION}' "
                f"(arg '{path_key}')",
                file=sys.stderr,
            )
            return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
