{ ... }:

{
  imports = [ ./live-dotfiles.nix ];

  # Personal files only: Doom manages its writable checkout and packages.
  dotfiles.configFiles = {
    "doom/init.el" = "doom/init.el";
    "doom/config.el" = "doom/config.el";
    "doom/packages.el" = "doom/packages.el";
  };
}
