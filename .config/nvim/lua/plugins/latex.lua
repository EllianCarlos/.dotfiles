return {
  {
    "saghen/blink.cmp",
    dependencies = {
      "krissen/blink-cmp-bibtex",
    },
    opts = function(_, opts)
      table.insert(opts.sources.default, "bibtex")
      opts.sources.providers.bibtex = {
        module = "blink-cmp-bibtex",
        name = "BibTeX",
        min_keyword_length = 2,
        score_offset = 10,
        async = true,
      }
      return opts
    end,
  },
}
