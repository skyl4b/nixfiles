config:

let
  home = config.home-manager.users.skylab;
in {
  hostName = config.networking.hostName;
  stateVersions = {
    system = config.system.stateVersion;
    home = home.home.stateVersion;
  };
  hardware = {
    fileSystems = builtins.mapAttrs (_: fs: {
      inherit (fs) device fsType options neededForBoot;
    }) config.fileSystems;
    swapDevices = map (swap: { inherit (swap) device; }) config.swapDevices;
    inherit (config.boot) kernelModules blacklistedKernelModules;
    initrd = {
      inherit (config.boot.initrd) availableKernelModules kernelModules;
    };
    prime = {
      inherit (config.hardware.nvidia.prime) intelBusId amdgpuBusId nvidiaBusId;
      inherit (config.hardware.nvidia.prime.offload) enable enableOffloadCmd;
    };
    graphicsPackages = map toString config.hardware.graphics.extraPackages;
    zram = {
      inherit (config.zramSwap) enable memoryPercent algorithm;
    };
    bootMenuLimit = config.boot.loader.systemd-boot.configurationLimit;
  };
  locale = {
    timeZone = config.time.timeZone;
    inherit (config.i18n) defaultLocale extraLocaleSettings;
    keyMap = config.console.keyMap;
  };
  networking = {
    inherit (config.networking) useDHCP;
    inherit (config.networking.networkmanager) enable dns;
    inherit (config.networking.firewall) allowedTCPPorts allowedUDPPorts;
    firewallEnabled = config.networking.firewall.enable;
    firewall = {
      inherit (config.networking.firewall)
        allowedTCPPortRanges allowedUDPPortRanges trustedInterfaces
        checkReversePath allowPing filterForward;
      interfaces = builtins.mapAttrs (_: interface: {
        inherit (interface) allowedTCPPorts allowedUDPPorts allowedTCPPortRanges allowedUDPPortRanges;
      }) config.networking.firewall.interfaces;
      nftables = config.networking.nftables.enable;
    };
    resolved = config.services.resolved.enable;
    tailscale = config.services.tailscale.enable;
    tailscalePolicy = {
      inherit (config.services.tailscale)
        openFirewall port interfaceName useRoutingFeatures extraUpFlags extraSetFlags extraDaemonFlags;
      autoConnect = config.services.tailscale.authKeyFile != null;
    };
    avahi = {
      inherit (config.services.avahi)
        enable nssmdns4 nssmdns6 openFirewall allowInterfaces denyInterfaces
        allowPointToPoint wideArea reflector;
      publish = {
        inherit (config.services.avahi.publish) enable userServices addresses hinfo workstation domain;
      };
    };
  };
  access = {
    ssh = {
      inherit (config.services.openssh) enable openFirewall ports;
      inherit (config.services.openssh.settings)
        PubkeyAuthentication PasswordAuthentication KbdInteractiveAuthentication PermitRootLogin;
      authorizedKeys = config.users.users.skylab.openssh.authorizedKeys.keys;
    };
    printing = {
      inherit (config.services.printing) listenAddresses openFirewall defaultShared browsing;
    };
    docker = {
      inherit (config.virtualisation.docker) listenOptions extraOptions;
      rootless = config.virtualisation.docker.rootless.enable;
    };
    libvirtd = {
      inherit (config.virtualisation.libvirtd) extraConfig extraOptions;
      qemuRunAsRoot = config.virtualisation.libvirtd.qemu.runAsRoot;
      daemonArgs =
        if config.virtualisation.libvirtd.enable then
          config.systemd.services.libvirtd.environment.LIBVIRTD_ARGS
        else null;
    };
    gnomeRemoteDesktop = config.services.gnome.gnome-remote-desktop.enable;
  };
  services = {
    inherit (config.services.xserver) enable xkb videoDrivers;
    printing = config.services.printing.enable;
    pulseaudio = config.services.pulseaudio.enable;
    gdm = config.services.displayManager.gdm.enable;
    pipewire = {
      inherit (config.services.pipewire) enable pulse jack;
      alsa = {
        inherit (config.services.pipewire.alsa) enable support32Bit;
      };
    };
    bluetooth = config.hardware.bluetooth.enable;
    libinput = config.services.libinput.enable;
    flatpak = config.services.flatpak.enable;
    fwupd = config.services.fwupd.enable;
    thermald = config.services.thermald.enable;
    inputRemapper = {
      inherit (config.services.input-remapper) enable enableUdevRules;
    };
    docker = config.virtualisation.docker.enable;
    podman = config.virtualisation.podman.enable;
    libvirtd = config.virtualisation.libvirtd.enable;
    virtManager = config.programs.virt-manager.enable;
    waydroid = config.virtualisation.waydroid.enable;
    lxc = config.virtualisation.lxc.enable;
    gnome = config.services.desktopManager.gnome.enable;
    cosmic = config.services.desktopManager.cosmic.enable;
    kdeconnect = config.programs.kdeconnect.enable;
  };
  containers = {
    nvidiaCdi = config.hardware.nvidia-container-toolkit.enable;
    dockerVersion = config.virtualisation.docker.package.version;
    dockerDaemon = config.virtualisation.docker.daemon.settings;
    podmanSettings = config.virtualisation.containers.containersConf.settings;
    podman = {
      inherit (config.virtualisation.podman) dockerCompat;
      dockerSocket = config.virtualisation.podman.dockerSocket.enable;
      defaultNetwork = config.virtualisation.podman.defaultNetwork.settings;
    };
    waydroid =
      if config.virtualisation.waydroid.enable then {
        package = toString config.virtualisation.waydroid.package;
        inherit (config.systemd.services.waydroid-container) wantedBy;
      } else null;
    legacyNvidiaConfig = builtins.hasAttr "nvidia-container-runtime/config.toml" config.environment.etc;
    cdiGenerator =
      if config.hardware.nvidia-container-toolkit.enable then
        let service = config.systemd.services.nvidia-container-toolkit-cdi-generator;
        in {
          inherit (service) wantedBy requiredBy;
          inherit (service.serviceConfig) Type RuntimeDirectory RemainAfterExit ExecStart ExecStartPre;
        }
      else null;
  };
  user = {
    inherit (config.users.users.skylab) isNormalUser description home extraGroups;
  };
  nix = {
    inherit (config.nix) settings;
    inherit (config.nix.gc) automatic dates options;
    optimise = config.nix.optimise.automatic;
    buildLimits = {
      inherit (config.nix.settings) max-jobs cores;
    };
    cleanup = {
      inherit (config.programs.nh.clean) enable dates extraArgs;
    };
  };
  packages = {
    system = map toString config.environment.systemPackages;
    home = map toString home.home.packages;
  };
  homeIntegration = {
    keyboard = home.home.keyboard;
    inherit (config.home-manager) useGlobalPkgs useUserPackages;
    inherit (home.home) sessionVariables sessionPath shellAliases;
    qt = {
      platformTheme = home.qt.platformTheme.name;
      style = home.qt.style.name;
      systemdVariables = home.systemd.user.sessionVariables;
    };
  };
}
