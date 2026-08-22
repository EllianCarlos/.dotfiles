# Auto-routes PipeWire's default sink/source to the Logitech G535 headset
# when its USB dongle connects, and back to the built-in audio when it
# disconnects. Triggered by a udev rule in
# ../../nixos/modules/hardware/audio.nix, which sets
# ENV{SYSTEMD_USER_WANTS} on the G535's USB add/remove events -- this is
# the supported way for a root udev rule to start a --user systemd unit in
# the active graphical session. It does not depend on
# graphical-session.target, which never activates in this Hyprland setup
# (systemd.user.services here are started directly by udev, not via
# Install.WantedBy).
{ pkgs, ... }:
let
  sink = "alsa_output.usb-Logitech_G535_Wireless_Gaming_Headset-00.analog-stereo";
  source = "alsa_input.usb-Logitech_G535_Wireless_Gaming_Headset-00.mono-fallback";
  card = "alsa_card.usb-Logitech_G535_Wireless_Gaming_Headset-00";
  builtinSink = "alsa_output.pci-0000_00_1f.3.iec958-stereo";
  builtinSource = "alsa_input.pci-0000_00_1f.3.analog-stereo";

  g535-audio-connect = pkgs.writeShellApplication {
    name = "g535-audio-connect";
    runtimeInputs = [ pkgs.pulseaudio ];
    text = ''
      # PipeWire registers the ALSA card asynchronously after the USB add
      # event -- wait for both nodes to exist before routing to them.
      for _ in $(seq 1 20); do
        if pactl list short sinks | grep -q "${sink}" \
          && pactl list short sources | grep -q "${source}"; then
          break
        fi
        sleep 0.5
      done

      # output:analog-stereo alone has no mic port; this profile does.
      # This is the fix for Discord (or anything else) not detecting the
      # headset mic -- also acts as a safety net if the profile ever
      # reverts to output-only.
      pactl set-card-profile "${card}" output:analog-stereo+input:mono-fallback

      pactl set-default-sink "${sink}"
      pactl set-default-source "${source}"

      for i in $(pactl list short sink-inputs | cut -f1); do
        pactl move-sink-input "$i" "${sink}" || true
      done
      for i in $(pactl list short source-outputs | cut -f1); do
        pactl move-source-output "$i" "${source}" || true
      done
    '';
  };

  g535-audio-disconnect = pkgs.writeShellApplication {
    name = "g535-audio-disconnect";
    runtimeInputs = [ pkgs.pulseaudio ];
    text = ''
      pactl set-default-sink "${builtinSink}" || true
      pactl set-default-source "${builtinSource}" || true
    '';
  };
in
{
  systemd.user.services.g535-audio-connect = {
    Unit.Description = "Route default audio sink/source to the G535 headset on connect";
    Service = {
      Type = "oneshot";
      ExecStart = "${g535-audio-connect}/bin/g535-audio-connect";
    };
  };

  systemd.user.services.g535-audio-disconnect = {
    Unit.Description = "Route default audio sink/source back to built-in audio on G535 disconnect";
    Service = {
      Type = "oneshot";
      ExecStart = "${g535-audio-disconnect}/bin/g535-audio-disconnect";
    };
  };
}
