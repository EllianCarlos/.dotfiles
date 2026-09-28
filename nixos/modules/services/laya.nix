{ pkgs, ... }:

{
  # laya (github.com/NandhaKishorM/laya) has no server/CLI of its own -- it's a plain
  # importable Python library (pip install laya), unlike ollama. This wraps it in a
  # small FastAPI app (files/laya-server.py, a PEP 723 script that `uv run` resolves
  # and executes standalone, no project/venv bookkeeping needed) so other local
  # processes can reach it over HTTP the same way they reach ollama, without each of
  # them needing a Python env. Loopback-only, same as ollama's default -- no firewall
  # change needed.
  #
  # laya is not in nixpkgs and is still a young/fast-moving package, so -- same
  # rationale as agent-rag-mcp (.config/home-manager/pkgs/rag-mcp.nix) -- it's fetched
  # at run time via uv rather than vendored as a Nix derivation.
  #
  # Unlike services.ollama.enable = true, this has no `wantedBy`, so it does NOT
  # auto-start at boot: laya's models are small (hundreds of MB, not ollama's
  # multi-GB LLMs) and used occasionally, so there's no reason to hold RAM/VRAM for
  # them every boot. `laya-setup` (zsh.nix) starts it and waits for the first (slow:
  # uv dependency resolution + HF model download) request to finish loading;
  # `laya-start`/`laya-stop` are the quick daily toggle, same shape as ollama's.
  users.users.laya = {
    isSystemUser = true;
    group = "laya";
    home = "/mnt/nixdata/laya"; # HF + uv caches on the second disk -- NVMe root is tight
    createHome = true;
  };
  users.groups.laya = { };

  systemd.services.laya = {
    description = "laya HTTP wrapper (local decision-model server, loopback-only)";
    serviceConfig = {
      User = "laya";
      Group = "laya";
      WorkingDirectory = "/mnt/nixdata/laya";
      Environment = [
        "HOME=/mnt/nixdata/laya"
        "HF_HOME=/mnt/nixdata/laya/hf-cache"
        "UV_CACHE_DIR=/mnt/nixdata/laya/uv-cache"
        # Force nixpkgs' Python instead of letting uv fetch its own build (NixOS
        # compatibility, same fix as rag-mcp.nix).
        "UV_PYTHON=${pkgs.python312}/bin/python3.12"
        "UV_PYTHON_PREFERENCE=only-system"
        # manylinux wheels (torch et al.) need a normal FHS libstdc++ to dlopen.
        "LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib"
      ];
      ExecStart = "${pkgs.uv}/bin/uv run ${./files/laya-server.py} --host 127.0.0.1 --port 11436";
      Restart = "on-failure";
    };
  };
}
