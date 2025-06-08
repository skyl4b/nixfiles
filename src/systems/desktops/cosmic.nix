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
}
