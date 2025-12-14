# Configuration of a cosmic desktop environment
{ pkgs, ... }: {
  services = {
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
