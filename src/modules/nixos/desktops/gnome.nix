{ pkgs, ... }:

let
  extensions = with pkgs.gnomeExtensions; [
    appindicator
    dash-to-dock
    caffeine
    o-tiling
  ];
in
{
  services = {
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
  };

  environment.systemPackages = (with pkgs; [
    gnome-tweaks
    gnome-network-displays
  ]) ++ extensions;

  # User preferences take precedence over these unlocked system defaults.
  programs.dconf.profiles.user.databases = [
    {
      settings."org/gnome/shell".enabled-extensions =
        map (extension: extension.extensionUuid) extensions;
    }
  ];
}
