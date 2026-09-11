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

    # deepseek-r1:7b: highest-scoring model in `llmfit fit --perfect` that
    # also has a direct Ollama tag (score 87.8, 24.7 tok/s est. on the RX
    # 6600, Q6_K quant) -- a reasoning model, so it burns real output budget
    # on <think> tokens. qwen2.5-coder:7b sits alongside it as a
    # non-reasoning coding model: no <think> tax, so the same context budget
    # goes further per agentic turn. Both are wired into opencode as
    # separate agents (see opencode.nix's "local" vs "local-coder").
    loadModels = [ "deepseek-r1:7b" "qwen2.5-coder:7b" ];

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
