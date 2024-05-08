# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }: {
  # Include modules
  imports = [
    # Hardware specific configuration
    ./hardware/addw3.nix

    # Cachix caches
    ./cachix

    # Gnome desktop environment
    # ./desktops/gnome.nix

    # Hyprland desktop environment
    # ./desktops/hyprland.nix

    # Cosmic desktop environment
    ./desktops/cosmic.nix
  ];

  # Bootloader
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
  };

  # Networking configuration
  networking = {
    # Hostname
    hostName = "jupiter";
    # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

    # Configure network proxy if necessary
    # networking.proxy.default = "http://user:password@proxy:port/";
    # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    # Enable networking
    networkmanager.enable = true;
  };

  # Timezone settings
  time.timeZone = "America/Sao_Paulo";

  # Internationalisation configuration
  i18n = {
    defaultLocale = "en_US.UTF-8";

    extraLocaleSettings = {
      LC_ADDRESS = "en_IE.UTF-8";
      LC_IDENTIFICATION = "en_IE.UTF-8";
      LC_MEASUREMENT = "en_IE.UTF-8";
      LC_MONETARY = "en_IE.UTF-8";
      LC_NAME = "en_IE.UTF-8";
      LC_NUMERIC = "en_IE.UTF-8";
      LC_PAPER = "en_IE.UTF-8";
      LC_TELEPHONE = "en_IE.UTF-8";
      LC_TIME = "en_IE.UTF-8";
    };
  };

  # Enable portals
  xdg = {
    portal = {
      enable = true;
      xdgOpenUsePortal = true;
    };
  };

  # Setup services
  services = {
    xserver = {
      # Enable the X11 / Wayland windowing systems
      enable = true;

      # Configure keymap
      layout = "us";
      xkbVariant = "intl";

      # Enable touchpad support
      libinput.enable = true;

      # Greeter
      # displayManager.gdm.enable = true;
    };

    # greetd = {
    #   enable = true;
    #   settings = {
    #     default_session = {
    #       command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd Hyprland";
    #       user = "greeter";
    #     };
    #   };
    # };

    # Enable CUPS to print documents.
    printing.enable = true;

    # Setup audio with pipewire
    pipewire = {
      enable = true;

      # Audio drivers
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
      jack.enable = true;
    };

    # Enable flatpak
    flatpak.enable = true;

    # Enable firmware updater
    fwupd.enable = true;
  };

  # Configure console keymap
  console.keyMap = "us-acentos";

  # Enable sound with pipewire.
  sound.enable = true;

  hardware = {
    pulseaudio.enable = false;

    # Enable bluetooth support
    bluetooth.enable = true;
  };

  security.rtkit.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.skylab = {
    isNormalUser = true;
    description = "Eduardo Farinati Leite";
    extraGroups = [
      "wheel"
      "networkmanager"
      "adm"
      "docker"
      "kvm"
      "libvirtd"
      "video"
    ];
    # packages = with pkgs; [ ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Nix tools
    cachix

    # Hardware tools
    glxinfo
    libva-utils
    vulkan-tools
    lshw
    pciutils
    lm_sensors
    pulseaudio # CLI tools that work with pipewire
    psensor # Graphical sensors monitor

    # Basic utils for editing
    git
    curl
    neovim

    # Browsers
    firefox
    brave

    # XWayland tools
    xorg.xhost

    # Gnome tools
    gnome.gnome-software
    gnome.gnome-tweaks
    gnomeExtensions.appindicator
    gnomeExtensions.dash-to-dock

    # Misc tools
    xwaylandvideobridge # Fix screensharing with xwayland
    psmisc # Extra utilities that use procfs (killall for ex.)

    # Firmware updater
    firmware-manager
  ];

  # Program settings
  programs = {
    # Virtual machine software
    virt-manager.enable = true;

    # XWayland for legacy apps
    xwayland.enable = true;
  };

  # Use wayland on enabled chromium apps
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Nix package manager configuration
  nix = {
    # Enable nix experimental features
    settings.experimental-features = [ "nix-command" "flakes" ];
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 3d";
    };
  };

  # Enable the NixOS virtualisation module
  virtualisation = {
    docker.enable = true;
    libvirtd.enable = true;
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
