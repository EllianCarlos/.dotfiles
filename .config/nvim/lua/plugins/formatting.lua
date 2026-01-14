return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" }, -- Load the plugin before saving
  cmd = { "ConformInfo" },   -- Load if you run the info command
  keys = {
    {
      -- Customize this keybinding if you want
      "<leader>f",
      function()
        require("conform").format({ async = true, lsp_fallback = true })
      end,
      mode = "",
      desc = "Format buffer",
    },
  },
  opts = {
    -- Map filetypes to the formatters you installed in home.nix
    formatters_by_ft = {
      lua = { "stylua" },
      
      -- Web Dev: Use Prettierd (daemon) for speed
      javascript = { "prettierd" },
      typescript = { "prettierd" },
      javascriptreact = { "prettierd" },
      typescriptreact = { "prettierd" },
      css = { "prettierd" },
      html = { "prettierd" },
      json = { "prettierd" },
      yaml = { "prettierd" },
      markdown = { "prettierd" },
      
      -- Python
      python = { "black" },
      
      -- Rust (Rust Analyzer handles this usually, but 'rustfmt' is good backup)
      rust = { "rustfmt" },
      
      -- Shell
      sh = { "shfmt" },
      zsh = { "shfmt" },
      
      -- Nix
      nix = { "nixpkgs_fmt" },
      
      -- Kotlin
      kotlin = { "ktlint" },
    },

    -- Enable Format on Save
    format_on_save = {
      -- These options ensure it doesn't block your UI if formatting takes too long
      timeout_ms = 500,
      lsp_fallback = true,
    },
  },
}
