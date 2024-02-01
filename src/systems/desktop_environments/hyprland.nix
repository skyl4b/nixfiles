# Configuration of a hyprland base desktop using various utilities
# for a desktop environment-like experience
{ pkgs, ... }: {
  programs = {
    # Install the hyprland window manager
    hyprland.enable = true;

    # Panel / status bar
    waybar.enable = true;
  };

  # Gnome useful packages
  environment.systemPackages = with pkgs; [
    # Notification daemon
    dunst

    # App launcher (dmenu like)
    bemenu

    # Full screen app launcher (gnome like)
    nwg-drawer

    # Wallpaper utility
    hyprpaper

    # Color picker
    hyprpicker

    # Shade configuration tool (nightlight)
    hyprshade

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

    # Appearance settings
    qt5ct
    qt6ct
    nwg-look
  ];
}
