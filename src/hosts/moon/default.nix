{ config, inputs, lib, pkgs, ... }:

{
  # Include the device module once `just generate-hardware moon` has created it.
  imports = [
    inputs.agenix.nixosModules.default
    inputs.disko.nixosModules.disko
    ./disk-config.nix
    ../../modules/nixos/common.nix
    ../../modules/nixos/desktops/gnome.nix
    ../../modules/nixos/virtualisation/docker.nix
    ../../modules/nixos/virtualisation/podman.nix
    ../../modules/nixos/virtualisation/waydroid.nix
  ] ++ lib.optional (builtins.pathExists ./hardware-configuration.nix)
    ./hardware-configuration.nix;

  age = {
    identityPaths = [ "/var/lib/agenix/identity" ];
    secrets.skylab-password.file = ../../secrets/skylab-password.age;
  };
  users.users.skylab.hashedPasswordFile = config.age.secrets.skylab-password.path;

  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 2;
      };
      efi.canTouchEfiVariables = true;
    };
    initrd.kernelModules = [ "i915" ];
  };

  # Limit local build parallelism for the Surface Go 3's CPU and 8 GB RAM.
  # These hardware constraints are specific to Moon, not shared host defaults.
  nix.settings = {
    max-jobs = 1;
    cores = 2;
  };

  # Use Intel's adaptive thermal management during sustained work such as builds.
  services.thermald.enable = true;
  environment.systemPackages = with pkgs; [
    libcamera
    rnote
    xournalpp
  ];

  hardware = {
    enableRedistributableFirmware = true;
    graphics = {
      enable = true;
      extraPackages = [ pkgs.intel-media-driver ];
    };
    sensor.iio.enable = true;
  };

  # Initial system compatibility for the currently pinned 26.11 platform.
  system.stateVersion = "26.11";
}
