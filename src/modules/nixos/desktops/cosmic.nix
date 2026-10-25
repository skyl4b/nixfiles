# Configuration of a cosmic desktop environment
{ pkgs, ... }: {
  imports = [ ../caches/cosmic.nix ];

  services = {
    # Keep the reference host's existing power stack until hardware testing.
    power-profiles-daemon.enable = true;
    system76-scheduler.enable = false;

    # Login manager
    displayManager.cosmic-greeter.enable = true;

    desktopManager.cosmic = {
      # Cosmic DE
      enable = true;
      # XWayland
      xwayland.enable = true;
    };

  };
  # Enable sway + gammastep for night-light on Cosmic
  # as it is not implemented yet
  programs.sway = {
    enable = true;
    extraPackages = with pkgs; [
      gammastep
    ];
  };

  # Extra required fonts
  fonts = {
    packages = with pkgs; [
      # GTK main font
      adwaita-fonts
    ];
  };

  # Desktop packages
  environment.systemPackages = with pkgs; [
    # Gnome image viewer
    loupe
    # Gnome document viewer
    papers
  ];
}
