_: {
  # Enable the yazi TUI file manager
  enable = true;

  # Plugins
  # Smart open / change directory
  plugins.smart-enter = ./smart-enter;

  # Keymap
  keymap.manager.prepend_keymap = [
    # Enable smart open on 'l'
    {
      on = [ "l" ];
      run = "plugin --sync smart-enter";
      desc = "Enter the child directory, or open the file";
    }
    # Edit on "e"
    {
      on = [ "e" ];
      run = "shell '$EDITOR \"$@\"' --confirm --block";
      desc = "Open with editor";
    }
  ];

  # Theme
  catppuccin.enable = true;
}
