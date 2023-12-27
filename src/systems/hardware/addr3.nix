# Hardware specific configuration for my System76 Adder WS 3
{ config, lib, pkgs, modulesPath, ... }: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "thunderbolt" "sdhci_pci" ]
    ++ [ "system76" "system76-io" "system76-acpi" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];

  # Set kernel extra packages
  # boot.extraModulePackages = with config.boot.kernelPackages; [
  #   system76
  #   system76-acpi
  #   system76-io
  #   system76-power
  #   system76-scheduler
  # ];
  boot.extraModulePackages = with pkgs.linuxPackages; [
    system76
    system76-acpi
    system76-io
    system76-power
    system76-scheduler
  ];

  # Based on system76 own configuration
  # See: https://github.com/pop-os/system76-driver/blob/01d750d6e5108a23cf0a45e34aacc7304ecd7770/system76driver/products.py#L41
  boot.blacklistedKernelModules = [ "i2c_nvidia_gpu" "psmouse" ];
  boot.kernelParams = [ "acpi_backlight=vendor" ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/25815584-ced6-4da8-b0ed-6e122b47b661";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/B469-118C";
    fsType = "vfat";
  };

  fileSystems."/mnt/Drive2" = {
    device = "/dev/disk/by-uuid/6656192d-f79b-4a07-8379-7e31e9356bc7";
    fsType = "ext4";
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
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Enable openGL
  hardware.opengl = {
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

  # Nvidia drivers
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
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
  };
  virtualisation.docker.enableNvidia = true;

  # Systen76 firmware and utils
  hardware.system76.enableAll = true;
  hardware.system76.kernel-modules.enable = false;
  services.system76-scheduler.enable = true;
}
