{ pkgs, extras, ... }: {
  enable = true;

  # Set bat config
  config = { theme = "Catppuccin-mocha"; };

  # Add themes
  themes = {
    Catppuccin-mocha =
      builtins.readFile (extras.bat-theme + "/Catppuccin-mocha.tmTheme");
  };

  # Add extra useful tools
  extraPackages = with pkgs.bat-extras; [ batdiff batman batgrep batwatch ];
}
