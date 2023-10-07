{ pkgs, inputs, ... }: {
  enable = true;

  # Set bat config
  config = { theme = "Catppuccin-mocha"; };

  # Add themes
  themes = {
    Catppuccin-mocha = {
      src = inputs.bat-theme;
      file = "Catppuccin-mocha.tmTheme";
    };
  };

  # Add extra useful tools
  extraPackages = with pkgs.bat-extras; [ batdiff batman batgrep batwatch ];
}
