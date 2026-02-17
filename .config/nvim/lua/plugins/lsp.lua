return {
  "neovim/nvim-lspconfig",
  dependencies = {
    "saghen/blink.cmp",
  },
  config = function()
    local lspconfig = require("lspconfig")
    local capabilities = require("blink.cmp").get_lsp_capabilities()

    local servers = {
      "lua_ls",
      "nil_ls",
      "pyright",
      "rust_analyzer",
      "kotlin_language_server",
      "nim_langserver",
      "julials",
      "biome",
      "jsonls",
      "html",
      "cssls",
    }

    for _, server in ipairs(servers) do
      lspconfig[server].setup({
        capabilities = capabilities,
      })
    end
  end,
}
