{ ... }: {
  imports = [ ./live-dotfiles.nix ];

  programs.zellij = {
    enable = true;
    enableBashIntegration = true;
  };
  dotfiles.configFiles."zellij/config.kdl" = "zellij/config.kdl";
}
