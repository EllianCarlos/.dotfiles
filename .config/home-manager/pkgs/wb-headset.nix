# wb-headset (waybar-headsetcontrol) -- a ratatui TUI + waybar module
# wrapping the `headsetcontrol` CLI: shows headset battery in waybar and
# opens an interactive sidetone-control menu on click.
# https://github.com/Henriklmao/waybar-headsetcontrol -- not in nixpkgs.
{ pkgs, lib, ... }:
let
  pin = (import ../pins.nix).wb-headset;
  src = pkgs.fetchFromGitHub {
    inherit (pin) owner repo rev;
    hash = "sha256-4Xl/WZM1Mu4AUUQ2L9fHfFmGs7RRq/2HVrsQJp4jNKg=";
  };
in
pkgs.rustPlatform.buildRustPackage {
  pname = "wb-headset";
  version = "0.1.5";
  inherit src;

  # Cargo.lock is committed upstream (as of the pinned rev -- see pins.nix),
  # so the vendored dependency set is reproduced straight from it; no
  # separate cargoHash to maintain.
  cargoLock.lockFile = "${src}/Cargo.lock";

  meta = {
    description = "Waybar module + TUI for headset battery/sidetone via HeadsetControl";
    homepage = "https://github.com/Henriklmao/waybar-headsetcontrol";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "wb-headset";
  };
}
