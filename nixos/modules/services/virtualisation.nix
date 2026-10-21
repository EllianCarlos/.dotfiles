{ config, lib, pkgs, ... }:

{
  options.custom.vms.enable = lib.mkEnableOption "VM tooling (libvirt, virt-manager, qemu, libguestfs)";

  config = lib.mkIf config.custom.vms.enable {
    virtualisation.libvirtd.enable = true;
    programs.virt-manager.enable = true;

    users.users.elliancarlos.extraGroups = [ "libvirtd" "libvirt-qemu" ];

    environment.systemPackages = with pkgs; [
      libvirt
      libguestfs-with-appliance
      guestfs-tools
      (import <nixos-stable> {
        inherit system;
        config.allowUnfree = true;
      }).qemu_full
    ];
  };
}
