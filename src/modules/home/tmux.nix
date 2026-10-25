{ pkgs, ... }:

{
  imports = [ ./live-dotfiles.nix ];

  # The pinned tmux module always generates tmux.conf when enabled.
  home.packages = [ pkgs.tmux pkgs.xsel ];
  home.sessionVariables.TMUX_TMPDIR = ''''${XDG_RUNTIME_DIR:-"/run/user/$(id -u)"}'';

  dotfiles.configFiles."tmux/tmux.conf" = "tmux/tmux.conf";

  # Only the module knows store paths. Native config loads these stable paths.
  xdg.configFile = {
    "tmux/plugins/catppuccin".source = "${pkgs.tmuxPlugins.catppuccin}/share/tmux-plugins/catppuccin";
    "tmux/plugins/resurrect".source = "${pkgs.tmuxPlugins.resurrect}/share/tmux-plugins/resurrect";
  };
}
