{ lib, pkgs, ... }:

{
  imports = [ ./nix.nix ./caches/proton-drive.nix ];

  networking = {
    networkmanager.enable = true;
    # Service modules own the required port exceptions.
    firewall.enable = lib.mkDefault true;
    # Preserve the existing ingress policy across upstream default changes.
    firewall.checkReversePath = "strict";
  };

  time.timeZone = "America/Sao_Paulo";
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
  console.keyMap = lib.mkDefault "us-acentos";

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
  };

  services = {
    xserver = {
      enable = true;
      xkb = {
        layout = "us";
        variant = "intl";
      };
    };
    libinput.enable = true;
    printing = {
      enable = true;
      listenAddresses = [ "localhost:631" ];
      openFirewall = false;
      defaultShared = false;
    };
    # Both desktops use mDNS discovery; Mars also publishes user services.
    avahi = {
      openFirewall = true;
      reflector = false;
    };
    openssh = {
      enable = lib.mkDefault true;
      openFirewall = lib.mkDefault true;
      settings = {
        PubkeyAuthentication = lib.mkDefault true;
        PasswordAuthentication = lib.mkDefault false;
        KbdInteractiveAuthentication = lib.mkDefault false;
        PermitRootLogin = lib.mkDefault "no";
      };
    };
    tailscale = {
      enable = lib.mkDefault true;
      # Permit the configured UDP transport port for direct peer connections.
      openFirewall = lib.mkDefault true;
      useRoutingFeatures = lib.mkDefault "none";
    };
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
      jack.enable = true;
    };
    flatpak.enable = true;
    fwupd.enable = true;
    input-remapper = {
      enable = lib.mkDefault true;
      enableUdevRules = lib.mkDefault true;
    };
  };

  hardware.bluetooth.enable = true;
  security.rtkit.enable = true;
  # Compressed swap is a workstation default; hosts can opt out if needed.
  zramSwap.enable = lib.mkDefault true;

  environment.systemPackages = with pkgs; [
    # Required to manage this configuration from any account.
    just
    jq
    chatgpt
    cachix
    mesa-demos
    libva-utils
    vulkan-tools
    lshw
    pciutils
    lm_sensors
    pulseaudio
    git
    curl
    dos2unix
    neovim
    unzip
    firefox
    brave
    xhost
    psmisc
  ];

  programs.xwayland.enable = true;
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
