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
    # Toggle hidden files on "H"
    {
      on = [ "H" ];
      run = "hidden toggle";
      desc = "Toggle the visibility of hidden files";
    }
    # Help on "?"
    {
      on = [ "?" ];
      run = "help";
      desc = "Open help";
    }
  ];

  # Settings
  settings.manager = {
    show_hidden = false;
    sort_by = "natural";
    sort_sensitive = false;
    sort_dir_first = true;
  };

  # Theme
  catppuccin.enable = true;
}
