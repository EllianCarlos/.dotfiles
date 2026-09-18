{ ... }:

let
  pins = import /home/elliancarlos/Projects/.dotfiles/.config/home-manager/pins.nix;
  openlogi = builtins.getFlake "github:${pins.openlogi.owner}/${pins.openlogi.repo}/${pins.openlogi.rev}";
in
{
  imports = [ openlogi.nixosModules.default ];

  programs.openlogi.enable = true;
}
