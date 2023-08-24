{ pkgs, inputs, ... }: {
  enable = true;

  # Set bat config
  config = { theme = "Catppuccin-mocha"; };

  # Add themes
  themes = { Catppuccin-mocha = builtins.readFile inputs.bat-theme; };

  # Add extra useful tools
  extraPackages = with pkgs.bat-extras; [ batdiff batman batgrep batwatch ];
}
