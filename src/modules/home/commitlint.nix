{ ... }: {
  imports = [ ./live-dotfiles.nix ];

  dotfiles.configFiles."commitlint/commitlint.config.js" = "commitlint/commitlint.config.js";
}
