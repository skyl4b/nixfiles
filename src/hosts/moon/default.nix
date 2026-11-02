{ config, inputs, pkgs, ... }:

{
  imports = [
    inputs.agenix.nixosModules.default
    inputs.disko.nixosModules.disko
    ./disk-config.nix
    ./hardware-configuration.nix
    ./touchpad.nix
    ../../modules/nixos/common.nix
    ../../modules/nixos/desktops/gnome.nix
    ../../modules/nixos/virtualisation/docker.nix
    ../../modules/nixos/virtualisation/podman.nix
    ../../modules/nixos/virtualisation/waydroid.nix
  ];

  age = {
    identityPaths = [ "/var/lib/agenix/identity" ];
    secrets.skylab-password.file = ../../secrets/skylab-password.age;
  };
  users.users.skylab.hashedPasswordFile = config.age.secrets.skylab-password.path;

  boot = {
    # Upstream 7.2.10 passed three wake cycles after 6.18.56 failed
    # on the first cycle. Continue checking longer sleeps and suspend drain.
    kernelPackages = pkgs.linuxPackages_latest;
    # Surface Go 3 Type Cover initialization delay (USB_QUIRK_DELAY_INIT).
    # Active on Moon, but confirmed insufficient to fix suspend/resume on 6.18.56.
    # https://github.com/linux-surface/linux-surface/issues/1059
    kernelParams = [ "usbcore.quirks=045e:09b5:g" ];
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

  nixfiles.gnome.extraExtensions = with pkgs.gnomeExtensions; [
    # Allow rotation with the Type Cover attached, regardless of tablet-mode detection.
    screen-rotate
    # Touch navigation and on-screen keyboard improvements for tablet use.
    touchup
  ];
  programs.dconf.profiles.user.databases = [
    {
      settings."org/gnome/settings-daemon/peripherals/touchscreen".orientation-lock = false;
    }
  ];

  environment.systemPackages = with pkgs; [
    libcamera
    readest
    rnote
    xournalpp
    zapzap
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
