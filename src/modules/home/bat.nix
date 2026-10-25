{ pkgs, ... }: {
  imports = [ ./live-dotfiles.nix ];

  programs.bat = {
    enable = true;

    # Add extra useful tools
    extraPackages = with pkgs.bat-extras; [ batdiff batman batgrep batwatch ];
  };

  # Keep Home Manager's cache rebuild; config and theme remain native files.
  dotfiles.configFiles = {
    "bat/config" = "bat/config";
    "bat/themes" = "bat/themes";
    "bat/LICENSE-catppuccin" = "bat/LICENSE-catppuccin";
  };
}
