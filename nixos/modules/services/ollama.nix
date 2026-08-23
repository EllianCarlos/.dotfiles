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

    # Highest-scoring model in `llmfit fit --perfect` that also has a direct
    # Ollama tag (score 87.8, 24.7 tok/s est. on the RX 6600, Q6_K quant).
    loadModels = [ "deepseek-r1:7b" ];

    # Ollama's own default context is 4096 (sometimes 2048), far too small
    # for agentic coding requests (system prompt + tool schemas + file
    # content). llmfit validated 8192 as fully resident in the RX 6600's
    # 8GB VRAM (88% utilization, no CPU offload); 12288 pushes a modest 50%
    # past that, letting a slice of KV cache spill into system RAM (~5.3GB
    # free) rather than the full jump to 16384. Watch `oom-log` after
    # heavy sessions; drop back to 8192 if it gets used.
    environmentVariables.OLLAMA_CONTEXT_LENGTH = "12288";
  };

  # isSystemUser accounts do not get createHome by default; ollama's
  # WorkingDirectory needs /mnt/nixdata/ollama to exist before the service starts.
  users.users.ollama.createHome = true;
}
