{ pkgs, ... }: {
  # Enable "tmux", a terminal multiplexer
  enable = true;

  # Start windows at one
  baseIndex = 1;

  # 24 hour clock
  clock24 = true;

  # Don't ask for confirmation when killing a window
  # disableConfirmationPrompt = true;

  # Vi mode
  keyMode = "vi";

  # Enable mouse support
  mouse = true;

  # 256 color support
  terminal = "screen-256color";

  # Set the default shell
  shell = "$SHELL";

  # Extra configuration / plugins
  extraConfig = builtins.readFile ./tmux.conf;
  plugins = with pkgs.tmuxPlugins; [
    {
      plugin = catppuccin;
      extraConfig = ''
        # Catppuccin flavor
        set -g @catppuccin_flavour 'mocha'

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

        # Set the statusbar modules
        set -g @catppuccin_status_modules_right "session"
      '';
    }
  ];
}
