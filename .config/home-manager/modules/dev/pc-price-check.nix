{ pkgs, ... }:
{
  systemd.user.services.pc-price-check = {
    Unit.Description = "Spawn Claude Code for the PC upgrade price check when due";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash /home/elliancarlos/Projects/pc-upgrade/scripts/price-check-due.sh";
      Environment = [ "PATH=/run/current-system/sw/bin:/home/elliancarlos/.nix-profile/bin" ];
    };
  };

  systemd.user.timers.pc-price-check = {
    Unit.Description = "Hourly check whether the PC price check is due";
    Timer = {
      OnCalendar = "hourly";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
