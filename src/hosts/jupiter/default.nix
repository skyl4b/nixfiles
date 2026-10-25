{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/common.nix
    ../../modules/nixos/desktops/gnome.nix
    ../../modules/nixos/virtualisation/docker.nix
    ../../modules/nixos/virtualisation/libvirt.nix
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  environment.systemPackages = [ pkgs.firmware-manager ];

  system.stateVersion = "23.11";
}
