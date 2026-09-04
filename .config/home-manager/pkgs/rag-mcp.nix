# rag-mcp -- launcher for agent-rag-mcp (local hybrid-RAG MCP server).
#
# Single source of truth for how the RAG server is started, referenced by all
# three agent MCP configs (Claude via mcp.nix, Pi, OpenCode) so they share one
# command and one on-disk index.
#
# - `cd ~/rag` so agent-rag-mcp finds its config.yaml (it reads config from CWD).
# - Force nixpkgs' Python for uv: uv's managed-Python downloads are generic
#   dynamically-linked binaries NixOS can't run without nix-ld (same reason
#   postgres-mcp sets UV_PYTHON in modules/ai/mcp.nix).
# - `uvx` fetches the pinned agent-rag-mcp version and caches it under ~/.cache/uv.
{ pkgs, ... }:
pkgs.writeShellScriptBin "rag-mcp" ''
  export UV_PYTHON=${pkgs.python312}/bin/python3.12
  export UV_PYTHON_PREFERENCE=only-system
  cd "$HOME/rag" 2>/dev/null || {
    echo "rag-mcp: ~/rag does not exist; run a Home Manager switch first" >&2
    exit 1
  }
  exec ${pkgs.uv}/bin/uvx agent-rag-mcp@1.1.9 "$@"
''
