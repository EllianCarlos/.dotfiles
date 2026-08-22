# Evaluation harness for verifying home-manager refactors WITHOUT a rebuild.
#
# Usage:
#   nix-instantiate '<nixpkgs/nixos>' \
#     -A config.home-manager.users.elliancarlos.home.activationPackage \
#     -I nixos-config=$HOME/Projects/.dotfiles/.config/home-manager/checks/eval-check.nix
#
# Why programs.neovim is force-disabled: this machine tracks home-manager =
# master and nixos = nixos-unstable, and those two have skewed. nixpkgs'
# neovimUtils.makeVimPackageInfo returns userPluginViml = null on purpose
# ("redefine via userPluginConfigs"), while home-manager master still passes
# that field straight to lib.concatStringsSep. Every evaluation of the full
# config therefore dies with "expected a list but found null: null" before
# it reaches anything else. The skew is pre-existing and reproduces on a
# clean checkout; it is a channel problem, not a config problem. Disabling
# the module here lets the whole REST of the config be checked while the
# skew stands. Verify the neovim block separately -- see
# docs/superpowers/plans/2026-08-21-home-manager-restructure.md, Fact 6.
#
# This imports /etc/nixos/configuration.nix, which is the COPY of nixos/.
# That is fine for home-manager work: nixos/modules/core/user.nix imports
# home.nix by absolute path into this repository, so home.nix and everything
# it imports is read live from the working tree, not from the copy.
{ lib, ... }:
{
  imports = [ /etc/nixos/configuration.nix ];

  home-manager.users.elliancarlos.programs.neovim.enable = lib.mkForce false;
}
