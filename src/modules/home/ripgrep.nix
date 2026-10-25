{ config, ... }: {
  imports = [ ./live-dotfiles.nix ];

  programs.ripgrep.enable = true;
  home.sessionVariables.RIPGREP_CONFIG_PATH = "${config.xdg.configHome}/ripgrep/ripgreprc";
  dotfiles.configFiles."ripgrep/ripgreprc" = "ripgrep/ripgreprc";
}
