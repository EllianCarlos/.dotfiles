# Neovim, plus the language servers, formatters and linters it shells out
# to. The lua config itself lives in .config/nvim and is symlinked by
# modules/desktop/dotfiles.nix.
{ pkgs, lib, ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # home-manager (master) now computes this internally from
    # extraConfig/plugins and writes it to .config/nvim/init.lua whenever
    # non-empty -- which collides with dotfiles.nix's out-of-store symlink
    # for the whole .config/nvim directory. Force it empty so this repo's
    # own nvim/init.lua stays authoritative.
    initLua = lib.mkForce "";

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
