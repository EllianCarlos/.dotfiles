local endpoint = "http://localhost:11434"
local model = "qwen2.5-coder:3b"

local function ollama_has_model()
  if vim.fn.executable("curl") == 0 then
    return false
  end
  local ok, res = pcall(function()
    return vim.system({ "curl", "-s", "-m", "1", endpoint .. "/api/tags" }, { text = true }):wait()
  end)
  if not ok or res.code ~= 0 or not res.stdout then
    return false
  end
  return res.stdout:find(model, 1, true) ~= nil
end

return {
  "milanglacier/minuet-ai.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  event = "InsertEnter",
  cond = ollama_has_model,
  opts = {
    provider = "openai_fim_compatible",
    n_completions = 1,
    context_window = 512,
    request_timeout = 30,
    notify = "warn",
    provider_options = {
      openai_fim_compatible = {
        api_key = "TERM",
        name = "Ollama",
        end_point = endpoint .. "/v1/completions",
        model = model,
        optional = { max_tokens = 56, top_p = 0.9 },
      },
    },
    virtualtext = {
      auto_trigger_ft = { "*" },
      keymap = {
        accept = "<C-l>",
        accept_line = "<A-l>",
        prev = "<A-[>",
        next = "<A-]>",
        dismiss = "<A-e>",
      },
    },
  },
}
