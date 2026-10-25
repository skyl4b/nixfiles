{ ... }: {
  imports = [ ./live-dotfiles.nix ];

  programs.bottom.enable = true;
  dotfiles.configFiles = {
    "bottom/bottom.toml" = "bottom/bottom.toml";
    "bottom/LICENSE-catppuccin" = "bottom/LICENSE-catppuccin";
  };
}
