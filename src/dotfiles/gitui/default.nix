{ ... }: {
  enable = true;

  # Keybindings configuration
  keyConfig = builtins.readFile ./key_config.ron;

  # Set theme
  theme = builtins.readFile ./theme.ron;
}
