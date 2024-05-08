{ pkgs, ... }: {
  enable = true;

  # Theme
  catppuccin.enable = true;

  # Add extra useful tools
  extraPackages = with pkgs.bat-extras; [ batdiff batman batgrep batwatch ];
}
