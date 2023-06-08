{ pkgs, ... }: {
  # Import each program's configuration
  direnv = import dotfiles/direnv/config.nix;
  git = import dotfiles/git.nix;
  hyfetch = import dotfiles/hyfetch.nix { inherit pkgs; };
  starship = import dotfiles/starship.nix;
  tealdeer = import dotfiles/tealdeer.nix;
  wezterm = import dotfiles/wezterm/config.nix { inherit pkgs; };

  # Let Home Manager install and manage itself
  home-manager.enable = true;
}
