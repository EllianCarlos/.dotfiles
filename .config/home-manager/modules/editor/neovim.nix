# Neovim, plus the language servers, formatters and linters it shells out
# to. The lua config itself lives in .config/nvim and is symlinked by
# modules/desktop/dotfiles.nix.
{ pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    extraPackages = with pkgs; [
      gcc
      gnumake
      unzip
      wget
      curl
      tree-sitter

      fzf
      trash-cli
      diffutils
      ghostscript
      tectonic

      lua-language-server
      stylua

      nil
      nixpkgs-fmt

      nodejs_22

      vscode-langservers-extracted

      prettier
      prettierd
      eslint_d
      biome
      stylelint

      pyright
      black

      rust-analyzer
      rustfmt

      kotlin-language-server
      ktlint

      shfmt
      shellcheck

      ast-grep
      detekt
      nimlangserver

      # --- C / C++ (also covers linux-kernel work) ---
      clang-tools # clangd (LSP) + clang-format (formatter)

      # --- LaTeX ---
      perlPackages.LatexIndent # provides latexindent.pl, used as the tex formatter
    ];
  };
}
