{ ... }: {
  imports = [ ./live-dotfiles.nix ];

  # Retain the package and existing weekly cache-update timer.
  programs.tealdeer.enable = true;
  dotfiles.configFiles."tealdeer/config.toml" = "tealdeer/config.toml";
}
