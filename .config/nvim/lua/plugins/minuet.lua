local endpoint = "http://localhost:11434"
local model = "qwen2.5-coder:3b"
local related_max_chars = 3000

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

local function rust_candidates(path)
  local root = vim.fs.root(path, "Cargo.toml")
  if not root then
    return {}
  end
  local rel = path:sub(#root + 2)
  local stem = vim.fn.fnamemodify(rel, ":t:r")
  local dir = vim.fn.fnamemodify(rel, ":h")

  if rel:match("^tests/") then
    local name = rel:gsub("^tests/", ""):gsub("%.rs$", "")
    return { root .. "/src/" .. name .. ".rs", root .. "/src/" .. name .. "/mod.rs" }
  end
  if stem == "tests" then
    return { root .. "/" .. dir .. ".rs", root .. "/" .. dir .. "/mod.rs" }
  end
  local base = stem:match("^(.-)_tests?$")
  if base then
    return { root .. "/" .. dir .. "/" .. base .. ".rs" }
  end

  local mod_dir = stem == "mod" and dir or dir .. "/" .. stem
  local name = mod_dir:gsub("^src/?", "")
  local out = {
    root .. "/" .. mod_dir .. "/tests.rs",
    root .. "/" .. dir .. "/" .. stem .. "_test.rs",
    root .. "/" .. dir .. "/" .. stem .. "_tests.rs",
  }
  if name ~= "" then
    table.insert(out, root .. "/tests/" .. name .. ".rs")
  end
  return out
end

local function generic_candidates(path)
  local dir = vim.fn.fnamemodify(path, ":h") .. "/"
  local file = vim.fn.fnamemodify(path, ":t")
  local ext = vim.fn.fnamemodify(path, ":e")
  local base = file:match("^(.-)[._]test%.%w+$")
    or file:match("^(.-)[._]spec%.%w+$")
    or file:match("^test_(.-)%.%w+$")
  if base then
    return { dir .. base .. "." .. ext }
  end
  local stem = vim.fn.fnamemodify(path, ":t:r")
  return {
    dir .. stem .. "_test." .. ext,
    dir .. stem .. ".test." .. ext,
    dir .. stem .. ".spec." .. ext,
    dir .. "test_" .. stem .. "." .. ext,
  }
end

local function read_related(path)
  local buf = vim.fn.bufnr(path)
  local lines
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
    lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  elseif vim.uv.fs_stat(path) then
    lines = vim.fn.readfile(path, "", 400)
  else
    return nil
  end
  return table.concat(lines, "\n"):sub(1, related_max_chars)
end

local function related_context()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    return ""
  end
  local candidates = vim.bo.filetype == "rust" and rust_candidates(path) or generic_candidates(path)
  local cs = vim.bo.commentstring:find("%%s") and vim.bo.commentstring or "# %s"
  for _, candidate in ipairs(candidates) do
    local text = candidate ~= path and read_related(candidate)
    if text then
      return cs:format("Related file: " .. vim.fn.fnamemodify(candidate, ":~:."))
        .. "\n"
        .. text
        .. "\n\n"
        .. cs:format("Current file: " .. vim.fn.fnamemodify(path, ":~:."))
        .. "\n"
    end
  end
  return ""
end

local function fim_prompt(before, _, _)
  local utils = require("minuet.utils")
  return related_context() .. utils.add_language_comment() .. "\n" .. utils.add_tab_comment() .. "\n" .. before
end

return {
  "milanglacier/minuet-ai.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  event = { "BufReadPre", "BufNewFile" },
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
        template = {
          prompt = fim_prompt,
          suffix = function(_, after, _)
            return after
          end,
        },
      },
    },
    virtualtext = {
      auto_trigger_ft = { "*" },
      show_on_completion_menu = true,
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
