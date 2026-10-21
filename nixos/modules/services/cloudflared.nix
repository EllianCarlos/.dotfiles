{ pkgs, ... }:

{
  systemd.services.cloudflared-collie = {
    description = "Cloudflare Tunnel for Collie (127.0.0.1:8787)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "/var/lib/cloudflared/collie.token";
    serviceConfig = {
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token-file %d/token";
      LoadCredential = "token:/var/lib/cloudflared/collie.token";
      DynamicUser = true;
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
