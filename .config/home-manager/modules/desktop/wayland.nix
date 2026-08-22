# Wayland session helpers: launcher, notifications.
#
# Note: graphical-session.target never activates in this Hyprland setup, so
# a unit that only has Install.WantedBy = [ "graphical-session.target" ]
# shows as enabled but stays inactive. Both mako and vicinae are actually
# started by exec-once lines in .config/hypr/hyprland.conf. The vicinae unit
# below is kept for the dependency metadata, not as the start mechanism.
{ pkgs, ... }:
{
  programs.wofi = {
    enable = true;
  };

  services.mako = {
    enable = true;
  };

  # Vicinae launcher daemon (bound to SUPER + SPACE in hyprland.conf).
  # No home-manager module upstream yet, so the unit is declared by hand.
  systemd.user.services.vicinae = {
    Unit = {
      Description = "Vicinae launcher daemon";
      Documentation = "https://docs.vicinae.com";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      Requires = [ "dbus.socket" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.vicinae}/bin/vicinae server";
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      Restart = "on-failure";
      RestartSec = 3;
      KillMode = "process";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
