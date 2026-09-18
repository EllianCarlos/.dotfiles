{ pkgs, ... }:

{
  # Radeon RX 6600 uses the Vulkan backend (confirmed via `llmfit doctor`).
  # ollama-rocm is not needed: RX 6600 (gfx1032) is not officially ROCm-supported,
  # and ollama-vulkan is ~20x smaller on disk.
  services.ollama = {
    enable = true;
    package = pkgs.ollama-vulkan;

    # Static user so the model directory has stable, predictable ownership.
    # Models live on the second sda partition (/mnt/nixdata), not on the
    # nearly-full NVMe root, to avoid draining the system disk.
    user = "ollama";
    group = "ollama";
    home = "/mnt/nixdata/ollama"; # modelsDir defaults to "${home}/models"

    # Started with deepseek-r1:7b + qwen2.5-coder:7b (llmfit-picked reasoning
    # + coding pair) and briefly added phi4-mini:3.8b alongside qwen3.5:4b
    # and lfm2.5:8b; dropped back down to just these two newer, smaller
    # models per user request. qwen3.5:4b is thinking+tool-use capable;
    # lfm2.5:8b is a MoE (~1B active params) purpose-built for tool calling
    # on consumer hardware. Each is wired into opencode as its own agent
    # (see opencode.nix's "local-qwen" / "local-lfm").
    loadModels = [
      "qwen3.5:4b"
      "lfm2.5:8b"
    ];

    # Ollama's own default context is 4096 (sometimes 2048), far too small
    # for agentic coding requests (system prompt + tool schemas + file
    # content). llmfit validated 8192 as fully resident in the RX 6600's
    # 8GB VRAM (88% utilization, no CPU offload); a bare 12288 already
    # pushed 50% past that, spilling a slice of KV cache into system RAM.
    # OLLAMA_KV_CACHE_TYPE=q8_0 quantizes the KV cache itself (needs
    # flash attention, already on via llama-server's --flash-attn auto),
    # roughly halving VRAM cost per context token -- so 24576 here costs
    # about what unquantized 12288 did, restoring full VRAM residency
    # instead of the CPU spill. Watch `oom-log` after heavy sessions; drop
    # back to 12288 (or q4_0, a further ~2x on top of q8_0) if it gets used.
    environmentVariables.OLLAMA_CONTEXT_LENGTH = "24576";
    environmentVariables.OLLAMA_KV_CACHE_TYPE = "q8_0";
  };

  # isSystemUser accounts do not get createHome by default; ollama's
  # WorkingDirectory needs /mnt/nixdata/ollama to exist before the service starts.
  users.users.ollama.createHome = true;
}
