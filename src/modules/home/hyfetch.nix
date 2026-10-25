{ config, ... }: {
  imports = [ ./live-dotfiles.nix ];

  # The upstream module declares a generated config even with empty settings.
  # Install its package directly so the native file keeps a single owner.
  home.packages = [ config.programs.hyfetch.package ];
  dotfiles.configFiles."hyfetch.json" = "hyfetch/hyfetch.json";
}
