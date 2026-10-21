return {
  {
    "mrcjkb/rustaceanvim",
    opts = {
      server = {
        default_settings = {
          ["rust-analyzer"] = {
            check = { command = "clippy" },
            cargo = { allFeatures = true },
            procMacro = { enable = true },
            completion = { autoimport = { enable = true }, autoself = { enable = true } },
            imports = { granularity = { group = "module" }, prefix = "self" },
          },
        },
      },
    },
  },
}
