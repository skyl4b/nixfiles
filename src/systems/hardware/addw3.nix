# Hardware specific configuration for my System76 Adder WS 3
{ config, lib, pkgs, modulesPath, ... }: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    initrd.availableKernelModules = [ "xhci_pci" "nvme" "thunderbolt" "sdhci_pci" ];
    initrd.kernelModules = [ ];
    kernelModules = [ "kvm-intel" ];

    # Based on system76 own configuration
    # See: https://github.com/pop-os/system76-driver/blob/01d750d6e5108a23cf0a45e34aacc7304ecd7770/system76driver/products.py#L41
    blacklistedKernelModules = [ "i2c_nvidia_gpu" "psmouse" ];
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/25815584-ced6-4da8-b0ed-6e122b47b661";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/B469-118C";
      fsType = "vfat";
    };
    "/mnt/Drive2" = {
      device = "/dev/disk/by-uuid/6656192d-f79b-4a07-8379-7e31e9356bc7";
      fsType = "ext4";
    };
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/8856768d-bd10-4849-baf6-b3260aef23e2"; }
  ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.eno0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp0s20f3.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware = {
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    intelgpu.loadInInitrd = true;

    # Enable openGL
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver
        vaapiVdpau
        libvdpau-va-gl
        nvidia-vaapi-driver
      ];
    };

    # Setup nvidia drivers
    nvidia = {
      modesetting.enable = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };

      # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
      # See: https://github.com/NixOS/nixos-hardware/issues/348#issuecomment-997123102
      powerManagement = {
        enable = true;

        # Fine-grained power management. Turns off GPU when not in use.
        # Experimental and only works on modern Nvidia GPUs (Turing or newer).
        finegrained = true;
      };

      # Ensure Nvidia GPU stays awake even during headless mode
      # See: https://stackoverflow.com/questions/45360006/what-does-persistence-mode-actually-do-which-reduces-cuda-startup-time
      # nvidiaPersistenced = true;
    };

    # System76 firmware and utils
    system76.enableAll = true;
    system76.power-daemon.enable = true;
  };

  services = {
    # Power profiles (Gnome) conflicts with system76-power
    # See: https://github.com/pop-os/system76-power/issues/299
    power-profiles-daemon.enable = false;

    # Nvidia driver dependencies
    xserver.videoDrivers = [ "nvidia" ];

    # System76 custom scheduler to prioritize low latency
    system76-scheduler.enable = true;

    # Gnome dual gpu integration
    switcherooControl.enable = true;

    # Bug gnome shell runs on discrete gpu when using wayland
    # See: https://gitlab.gnome.org/GNOME/mutter/-/issues/2969
    # And: https://discourse.nixos.org/t/dual-gpu-setup-nvidia-smi-shows-gnome-shell-and-doesnt-sleep/37681
    # gnome.gnome-remote-desktop.enable = false;
  };

  # Nvidia docker dependencies
  virtualisation.docker.enableNvidia = true;
}
