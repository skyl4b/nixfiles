# Configuration of a gnome desktop environment using a few custom extensions
# such as pop shell
{ pkgs, ... }: {
  # Enable the GNOME Desktop Environment
  services.xserver = {
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
  };

  # Gnome useful packages
  environment.systemPackages = with pkgs; [
    # Terminal
    ptyxis

    # Gnome specific tools
    gnome-software
    gnome-tweaks
    gnomeExtensions.appindicator
    gnomeExtensions.dash-to-dock
    gnomeExtensions.caffeine
    gdm-settings

    # Miracast / streaming
    gnome-network-displays

    # Pop shell
    gnomeExtensions.pop-shell
    pop-launcher
  ];

  # Configure kde connect to use gsconnect
  programs.kdeconnect.package = pkgs.gnomeExtensions.gsconnect;
}
