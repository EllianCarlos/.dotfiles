{ config, pkgs, ... }:

{
  # --- Recorded system history (atop) -----------------------------------------
  # Replay: atop -r /var/log/atop/atop_YYYYMMDD -b HH:MM
  programs.atop = {
    enable = true;
    atopService.enable = true;
    atopacctService.enable = true;
    atopRotateTimer.enable = true;
  };

  # --- Log sampling interval --------------------------------------------------
  systemd.services.atop.environment.LOGINTERVAL = "60";

  # --- Early OOM handling -----------------------------------------------------
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 8;
    enableNotifications = true;
  };
}
