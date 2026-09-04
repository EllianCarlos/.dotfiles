# Local hybrid-RAG over ~/rag, shared by Claude Code, Pi, and OpenCode.
#
# agent-rag-mcp (ChromaDB + Ollama qwen3-embedding) does retrieval; the cloud
# LLM does generation. This module owns everything AROUND the server: the
# config, the sources -> corpus conversion pipeline, the ingest, the manual
# `rag-reindex` command, and the `rag-watch` auto-reindex service. The server
# itself is launched by pkgs/rag-mcp.nix and wired into each agent's MCP config
# in modules/ai/{mcp,pi,opencode}.nix. See files/rag/SOP.md for operation.
{ config, pkgs, ... }:
let
  custom = import ../../pkgs { inherit pkgs; };

  # convert sources -> markdown/text corpus, then ingest headlessly.
  ragReindex = pkgs.writeShellApplication {
    name = "rag-reindex";
    runtimeInputs = [
      pkgs.uv # uvx markitdown; uv run --with mcp python ingest.py
      pkgs.pandoc # .tex -> markdown
      pkgs.coreutils
      pkgs.findutils
      custom.rag-mcp # ingest.py spawns `rag-mcp` over stdio
    ];
    text = builtins.readFile ../../files/rag/reindex.sh;
  };

  # recursive inotify watch that debounces and calls rag-reindex.
  ragWatch = pkgs.writeShellApplication {
    name = "rag-watch";
    runtimeInputs = [ pkgs.inotify-tools ragReindex ];
    text = builtins.readFile ../../files/rag/watch.sh;
  };
in
{
  home.packages = [ ragReindex ragWatch custom.rag-mcp ];

  home.file = {
    "rag/config.yaml".source = ../../files/rag/config.yaml;
    "rag/ingest.py".source = ../../files/rag/ingest.py;
    "rag/SOP.md".source = ../../files/rag/SOP.md;
  };

  # sources/ is the user's (a symlink target); corpus/ and chroma_db/ are
  # regenerable and must be writable, so they are created at activation rather
  # than managed as read-only Nix-store symlinks.
  home.activation.ragDirs = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/rag/sources" "$HOME/rag/corpus" "$HOME/rag/chroma_db"
  '';

  # Auto-reindex on change. inotify watch (not a systemd.path unit, which is
  # non-recursive) so a whole subtree of symlinked sources is covered.
  systemd.user.services.rag-watch = {
    Unit = {
      Description = "Watch ~/rag/sources and reindex the local RAG corpus";
      After = [ "default.target" ];
    };
    Service = {
      ExecStart = "${ragWatch}/bin/rag-watch";
      Restart = "on-failure";
      RestartSec = 15;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
