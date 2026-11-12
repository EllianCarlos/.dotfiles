# Wayland session helpers: launcher, notifications.
#
# Note: graphical-session.target never activates in this Hyprland setup, so
# a unit that only has Install.WantedBy = [ "graphical-session.target" ]
# shows as enabled but stays inactive. Mako is actually
# started by an exec-once line in .config/hypr/hyprland.conf.
{ pkgs, ... }:
{
  programs.wofi = {
    enable = true;
  };

  # mako's config is the tracked .config/mako/config (linked in dotfiles.nix);
  # services.mako would generate its own and clash, so only the package is installed.
  home.packages = [ pkgs.mako ];
}
