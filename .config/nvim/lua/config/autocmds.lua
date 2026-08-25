-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- LazyVim's core wrap_spell group covers "plaintex" but not "tex" (the
-- filetype vimtex actually assigns to real LaTeX documents), so mirror it here.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("tex_wrap_spell", { clear = true }),
  pattern = { "tex" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})
