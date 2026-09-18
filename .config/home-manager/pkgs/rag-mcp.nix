# rag-mcp -- launcher for agent-rag-mcp (local hybrid-RAG MCP server).
#
# Single source of truth for how the RAG server is started, referenced by all
# three agent MCP configs (Claude via mcp.nix, Pi, OpenCode) so they share one
# command and one on-disk index.
#
# - `RAG_CONFIG` is REQUIRED. agent-rag-mcp resolves its config in this order
#   (rag/config_loader.py -> load_config): explicit path -> $RAG_CONFIG ->
#   ~/.config/agent_rag/config.yaml -> <cwd>/config.yaml -> package default.
#   The CLI `--config` flag only reaches *some* of those call sites: the
#   embedder is built by a separate load_config() that ignores it, so with
#   --config alone the startup banner still shows the right embedder while the
#   real one falls back to the auto-bootstrapped
#   ~/.config/agent_rag/config.yaml (provider: openrouter) and the server dies
#   with "Pre-warm failed: OpenRouter API key is required". Exporting the env
#   var makes every load_config() call agree. --config is passed as well, for
#   the call sites that do honour it.
# - `LD_LIBRARY_PATH` is REQUIRED: agent-rag-mcp pulls manylinux binary wheels
#   (numpy, chromadb, ...) that dlopen libstdc++.so.6 from the FHS paths, which
#   don't exist on NixOS. Without this the server gets as far as pre-warming the
#   embedder and then dies with
#     "Importing the numpy C-extensions failed ...
#      Original error was: libstdc++.so.6: cannot open shared object file"
# - `cd ~/rag` is still kept so any relative path that survives in the config
#   resolves somewhere writable rather than into the read-only nix store.
# - Force nixpkgs' Python for uv: uv's managed-Python downloads are generic
#   dynamically-linked binaries NixOS can't run without nix-ld (same reason
#   postgres-mcp sets UV_PYTHON in modules/ai/mcp.nix).
# - `uvx` fetches the pinned agent-rag-mcp version and caches it under ~/.cache/uv.
{ pkgs, ... }:
pkgs.writeShellScriptBin "rag-mcp" ''
  export UV_PYTHON=${pkgs.python312}/bin/python3.12
  export UV_PYTHON_PREFERENCE=only-system
  export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  export RAG_CONFIG="$HOME/rag/config.yaml"
  cd "$HOME/rag" 2>/dev/null || {
    echo "rag-mcp: ~/rag does not exist; run a Home Manager switch first" >&2
    exit 1
  }
  exec ${pkgs.uv}/bin/uvx agent-rag-mcp@1.1.9 --config "$RAG_CONFIG" "$@"
''
