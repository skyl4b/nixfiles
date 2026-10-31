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

  # Use GNOME's KDE Connect implementation and the upstream firewall rules.
  programs.kdeconnect = {
    enable = true;
    package = pkgs.gnomeExtensions.gsconnect;
  };

  environment.systemPackages = (with pkgs; [
    gnome-tweaks
    gnome-network-displays
  ]) ++ extensions;

  # User preferences take precedence over these unlocked system defaults.
  programs.dconf.profiles.user.databases = [
    {
      settings."org/gnome/shell" = {
        always-show-log-out = true;
        enabled-extensions = map (extension: extension.extensionUuid)
          (extensions ++ [ pkgs.gnomeExtensions.gsconnect ]);
      };
    }
  ];
}
