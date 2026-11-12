{ pkgs, ... }:

let
  mkTunnel = { description, tokenFile }: {
    inherit description;
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = tokenFile;
    serviceConfig = {
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token-file %d/token";
      LoadCredential = "token:${tokenFile}";
      DynamicUser = true;
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
in
{
  systemd.services.cloudflared-collie = mkTunnel {
    description = "Cloudflare Tunnel for Collie (127.0.0.1:8787)";
    tokenFile = "/var/lib/cloudflared/collie.token";
  };

  systemd.services.cloudflared-pizza = mkTunnel {
    description = "Cloudflare Tunnel for pizza-delivery";
    tokenFile = "/etc/cloudflared/pizza.token";
  };
}
