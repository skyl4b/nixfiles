# Configuration of a hyprland base desktop using various utilities
# for a desktop environment-like experience
{ pkgs, ... }: {
  programs = {
    # Install the hyprland window manager
    hyprland.enable = true;

    # File manager
    thunar = {
      enable = true;
      plugins = with pkgs.xfce; [
        thunar-archive-plugin
        thunar-volman
        thunar-media-tags-plugin
      ];
    };

    # Phone / computer integration
    kdeconnect.enable = true;
  };

  # Necessary for swaylock, see: https://github.com/NixOS/nixpkgs/issues/158025
  security.pam.services.swaylock = { };

  services = {
    # Bluetooth configurarion
    blueman.enable = true;

    # Mount, trash, and other functionalities for thunar
    gvfs.enable = true;

    # Thumbnail support for images for thunar
    tumbler.enable = true;
  };

  # Fallback to gtk portal
  xdg.portal.extraPortals = with pkgs; [
    xdg-desktop-portal-gtk
  ];

  # Desktop packages
  environment.systemPackages = with pkgs; [
    # Panel / status bar
    nwg-panel

    # Notification daemon and GUI
    swaynotificationcenter

    # App launcher (dmenu like)
    bemenu

    # Full screen app launcher (gnome like)
    nwg-drawer

    # Power management
    nwg-bar

    # Application dock
    nwg-dock-hyprland

    # Polkit authentication agent
    libsForQt5.polkit-kde-agent

    # System sounds
    libcanberra-gtk3

    # Wallpaper utility
    hyprpaper

    # Color picker
    hyprpicker

    # Shade configuration tool (nightlight)
    hyprshade

    # Screen locker
    swaylock

    # Idle management daemon
    swayidle

    # On screen display for volume / brightness / etc
    swayosd

    # Gnome-like workspace switching
    hyprnome

    # Randr-like tool for wlroots compositors
    wlr-randr

    # Hyprland screenshot tool
    grimblast

    # System tray network manager
    networkmanagerapplet

    # Brightness control tool
    brightnessctl

    # Auto mount disks
    udiskie

    # GUI to configure displays
    nwg-displays

    # CLI utilities for xdg such as default apps
    xdg-utils
    glib

    # Volume control
    pavucontrol

    # PDF viewer
    libsForQt5.okular

    # Media player
    vlc

    # Image viewer
    loupe

    # System monitor
    mission-center

    # Calendar
    libsForQt5.merkuro

    # Theme
    gtk3
    gtk4
    gnome.adwaita-icon-theme
    adwaita-qt

    # Appearance settings
    qt5ct
    qt6ct
    nwg-look

    # Low battery notifications
    batsignal
  ];

  # QT Theme / style
  qt = {
    enable = true;
    platformTheme = "qt5ct";
  };
}
