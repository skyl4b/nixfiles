_: {
  # Enable wezterm, a modern terminal emulator
  enable = true;

  # Set wezterm config
  extraConfig = builtins.readFile ./wezterm.lua;
}
