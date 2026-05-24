{ config, pkgs, lib, ... }:

{
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    extraConfig.pipewire."combine-sink" = {
      "context.modules" = [
        {
          name = "libpipewire-module-combine-stream";
          args = {
            "combine.mode" = "sink";
            "node.name" = "combine-sink";
            "node.description" = "Combined";
            "combine.latency-compensate" = false;
            "combine.props"."audio.position" = [ "FL" "FR" ];
            "stream.props" = { };
            "stream.rules" = [
              {
                matches = [{ "media.class" = "Audio/Sink"; "node.name" = "~alsa_output.*"; }];
                actions."create-stream" = { };
              }
            ];
          };
        }
      ];
    };
  };
  environment.etc."wireplumber/wireplumber.conf.d/alsa-no-suspend.conf".text = ''
    monitor.alsa.rules = [
      {
        matches = [ { node.name = ~alsa_output.* } ]
        actions = {
          update-props = {
            session.suspend-timeout-seconds = 0
          }
        }
      }
    ]
  '';
  services.pulseaudio.enable = lib.mkForce false;
}

