-- TTY colorscheme for LazyVim. colors/tty.lua lives in ~/.config/nvim/colors/.
return {
  { "LazyVim/LazyVim", opts = { colorscheme = "tty" } },
  { "nvim-lualine/lualine.nvim", opts = function(_, opts)
      opts.options = opts.options or {}
      opts.options.theme = require("tty_lualine")
      opts.options.section_separators = ""
      opts.options.component_separators = { left = "│", right = "│" }
    end },
  { "akinsho/bufferline.nvim", opts = { options = { separator_style = { "", "" }, indicator = { style = "none" } } } },
}
