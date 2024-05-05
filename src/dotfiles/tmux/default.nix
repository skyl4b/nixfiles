{ pkgs, ... }: {
  # Enable "tmux", a terminal multiplexer
  enable = true;

  # Set ctrl + space as prefix
  prefix = "C-Space";

  # Start enumerating windows at one
  baseIndex = 1;

  # 24 hour clock
  clock24 = true;

  # Don't ask for confirmation when killing a window
  disableConfirmationPrompt = true;

  # Vi mode
  keyMode = "vi";

  # Enable mouse support
  mouse = true;

  # True color support
  terminal = "tmux-256color";

  # Set the default shell
  shell = "$SHELL";

  # Rather than constraining window size to the maximum size of any client 
  # connected to the *session*, constrain window size to the maximum size of any 
  # client connected to *that window*
  aggressiveResize = true;

  # Maximum number of lines held in window history
  historyLimit = 10000;

  # Extra configuration / plugins
  extraConfig = builtins.readFile ./tmux.conf;
  plugins = with pkgs.tmuxPlugins; [
    {
      plugin = catppuccin;
      extraConfig = ''
        # Catppuccin flavor
        set -g @catppuccin_flavour "mocha"

        # Style the statusbar
        set -g @catppuccin_window_left_separator ""
        set -g @catppuccin_window_right_separator " "
        set -g @catppuccin_window_middle_separator " █"
        set -g @catppuccin_window_number_position "right"
        set -g @catppuccin_window_default_fill "number"
        set -g @catppuccin_window_default_text "#W"
        set -g @catppuccin_window_current_fill "number"
        set -g @catppuccin_window_current_text "#W"
        set -g @catppuccin_status_left_separator  " "
        set -g @catppuccin_status_right_separator ""
        set -g @catppuccin_status_right_separator_inverse "no"
        set -g @catppuccin_status_fill "icon"
        set -g @catppuccin_status_connect_separator "no"
        set -g @catppuccin_window_current_background "#cdd6f4"

        # Set the statusbar modules
        set -g @catppuccin_status_modules_right "session"
      '';
    }

    {
      plugin = resurrect;
      extraConfig = ''
        # Tmux resurrect bindings (save and restore session)
        set -g @resurrect-save "S"
        set -g @resurrect-restore "R"
      '';
    }
  ];
}
