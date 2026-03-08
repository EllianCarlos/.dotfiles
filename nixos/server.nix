# Server services: SSH, Tailscale, PostgreSQL.
# Imported by configuration.nix.

{ config, pkgs, ... }:

{
  # OpenSSH for remote access
  services.openssh = {
    enable = true;
    settings = {
      # Prefer key-only auth; set to "prohibit-password" when keys are in place
      PasswordAuthentication = true; # Set to false once SSH keys are configured
      PermitRootLogin = "prohibit-password";
    };
  };

  # Tailscale for "backdoor" access when Cloudflare or home IP unavailable
  services.tailscale.enable = true;
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # Auth: run `tailscale up --authkey=YOUR_KEY` once after first boot,
  # or use services.tailscale.authKeyFile with a path (e.g. from sops-nix).

  # PostgreSQL
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;

    # App database and role (aligned with Phase 5 MVP)
    # Password: set via sops-nix (Phase 7) or initialScript; for now use peer/local.
    ensureDatabases = [ "home_server" ];
    ensureUsers = [
      {
        name = "home_server";
        ensureDBOwnership = true;
      }
    ];

    # Authentication: default is peer for local socket. When the app runs as
    # user home_server (e.g. systemd), it connects via peer. For TCP/password
    # (e.g. sops-nix secrets), add host rules with scram-sha-256 in a later phase.
  };

  environment.systemPackages = with pkgs; [ ];
}
