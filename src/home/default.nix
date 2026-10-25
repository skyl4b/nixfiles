{ pkgs, ... }:

{
  imports = [
    ../modules/home
  ];

  home = {
    sessionVariables = rec {
      EDITOR = "nvim";
      VISUAL = EDITOR;
    };
    sessionPath = [ "$HOME/.local/bin" ];
    shellAliases = { };
  };

  gtk = {
    enable = true;
    colorScheme = "dark";
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    # The legacy Adwaita-dark package only supplies a GTK3 stylesheet.
    gtk4.theme = null;
  };
  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style.name = "adwaita-dark";
  };

  xdg.enable = true;
  fonts.fontconfig.enable = true;
}
