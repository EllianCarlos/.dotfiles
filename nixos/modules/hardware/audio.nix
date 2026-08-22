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

  # `headsetcontrol` reads battery/sidetone/LED state from the G535 over
  # USB HID. It needs the udev rules its own build installs under
  # $out/lib/udev/rules.d -- services.udev.packages wires those into the
  # running udev, granting the user rw access to the device's hidraw nodes
  # without root.
  environment.systemPackages = [ pkgs.headsetcontrol ];
  services.udev.packages = [ pkgs.headsetcontrol ];

  # Auto-route the default sink/source to the G535 on USB connect/remove,
  # and back to built-in audio on disconnect. DEVTYPE=="usb_device" fires
  # once per physical (un)plug, on the composite USB device itself (ALSA's
  # sound-subsystem sub-nodes appear/vanish slightly later and asynchronously
  # -- the connect script itself waits for those). SYSTEMD_USER_WANTS starts
  # the matching --user unit in the active graphical session; the units
  # live in .config/home-manager/g535-audio.nix.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="046d", ATTR{idProduct}=="0ac4", TAG+="systemd", ENV{SYSTEMD_USER_WANTS}="g535-audio-connect.service"
    ACTION=="remove", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="046d", ATTR{idProduct}=="0ac4", TAG+="systemd", ENV{SYSTEMD_USER_WANTS}="g535-audio-disconnect.service"
  '';
}

