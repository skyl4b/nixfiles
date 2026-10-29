{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/common.nix
    ../../modules/nixos/desktops/cosmic.nix
    ../../modules/nixos/virtualisation/docker.nix
    ../../modules/nixos/virtualisation/podman.nix
    ../../modules/nixos/virtualisation/libvirt.nix
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking.networkmanager.dns = "systemd-resolved";
  services = {
    resolved.enable = true;
    avahi = {
      enable = true;
      nssmdns4 = true;
      nssmdns6 = true;
      publish = {
        enable = true;
        userServices = true;
      };
    };
  };
  hardware = {
    xone.enable = true;
    steam-hardware.enable = true;
  };
  programs.kdeconnect.enable = true;

  system.stateVersion = "24.11";
}
