{ config, pkgs, ... }:

{
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk pkgs.xdg-desktop-portal-hyprland ];
    config.common.default = "*";
  };

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # MTP support (e.g. Kindle Paperwhite over USB) via gio/gvfs.
  # services.gvfs.enable only wires the gvfsd daemon (dbus/systemd-activated,
  # ships no shell binary). The `gio` command line tool itself lives in
  # glib's bin output, which nothing else on this system pulls in, so it
  # must be listed explicitly to land on PATH.
  services.gvfs.enable = true;
  environment.systemPackages = [ pkgs.glib pkgs.unzip ];

  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
    NIXOS_OZONE_WL = "1";
  };
}