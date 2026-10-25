{ ... }:

{
  imports = [ ./live-dotfiles.nix ];

  # Retain the package and yy shell wrapper without generating native files.
  programs.yazi.enable = true;
  programs.yazi.shellWrapperName = "yy";

  dotfiles.configFiles = {
    "yazi/yazi.toml" = "yazi/yazi.toml";
    "yazi/keymap.toml" = "yazi/keymap.toml";
    "yazi/theme.toml" = "yazi/theme.toml";
    "yazi/flavors/catppuccin-mocha.yazi" = "yazi/flavors/catppuccin-mocha.yazi";
    "yazi/plugins/smart-enter.yazi" = "yazi/plugins/smart-enter.yazi";
  };
}
