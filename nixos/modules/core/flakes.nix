{ config, pkgs, ... }:

let 
  cursor-flake = builtins.getFlake "github:omarcresp/cursor-flake";
  system = "x86_64-linux";
in
{
  environment.systemPackages = with pkgs; [
    cursor-flake.packages.${system}.default
  ];
}