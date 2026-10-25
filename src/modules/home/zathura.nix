{ config, ... }: {
  imports = [ ./live-dotfiles.nix ];

  # The pinned module always generates zathurarc when enabled.
  home.packages = [ config.programs.zathura.package ];
  dotfiles.configFiles."zathura/zathurarc" = "zathura/zathurarc";
}
