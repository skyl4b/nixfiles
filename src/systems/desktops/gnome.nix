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
    # Gnome specific tools
    gnome.gnome-software
    gnome-tweaks
    gnomeExtensions.appindicator
    gnomeExtensions.dash-to-dock

    # Pop shell
    gnomeExtensions.pop-shell
    pop-launcher
  ];
}
