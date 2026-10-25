{ config, ... }:

{
  imports = [ ./live-dotfiles.nix ];

  # The pinned Gitui module always generates both RON files when enabled.
  home.packages = [ config.programs.gitui.package ];
  dotfiles.configFiles = {
    "gitui/key_bindings.ron" = "gitui/key_bindings.ron";
    "gitui/theme.ron" = "gitui/theme.ron";
    "gitui/LICENSE-catppuccin" = "gitui/LICENSE-catppuccin";
  };
}
