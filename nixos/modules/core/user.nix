{ config, pkgs, ... }:

{
  programs.zsh.enable = true;
  users.users.elliancarlos = {
    isNormalUser = true;
    description = "Ellian Carlos";
    extraGroups = [ "networkmanager" "wheel" "video" "audio" "render" ];
    shell = pkgs.zsh;
  };

  home-manager.users.elliancarlos = import /home/elliancarlos/Projects/.dotfiles/.config/home-manager/home.nix;
  home-manager.backupFileExtension = "backup";
}