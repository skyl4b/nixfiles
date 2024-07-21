_: {
  # Enable the yazi TUI file manager
  enable = true;

  # Plugins
  # Smart open / change directory
  plugins.smart-enter = ./smart-enter;

  # Keymap
  # Enable smart open on 'l'
  keymap.manager.prepend_keymap = [{
    on = [ "l" ];
    run = "plugin --sync smart-enter";
    desc = "Enter the child directory, or open the file";
  }];

  # Theme
  catppuccin.enable = true;
}
