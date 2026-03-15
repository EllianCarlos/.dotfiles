{ config, pkgs, ... }:

{
  services.tailscale.enable = true;
  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    checkReversePath = "loose";
    trustedInterfaces = [ "tailscale0" "virbr0" ]; # Shared trusted interfaces
    allowedUDPPorts = [ config.services.tailscale.port ];
  };

  systemd.services.tailscaled.serviceConfig.Environment = [ 
    "TS_DEBUG_FIREWALL_MODE=nftables" 
  ];
  
  systemd.network.wait-online.enable = false; 
  boot.initrd.systemd.network.wait-online.enable = false;
}