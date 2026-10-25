{ pkgs, ... }:

{
  imports = [ ./live-dotfiles.nix ];

  # The pinned programs.git module always generates git/config when enabled.
  # Install the binaries directly so the native files have a single owner.
  home.packages = [ pkgs.git pkgs.gnupg ];

  dotfiles.configFiles = {
    "git/config" = "git/config";
    "git/ignore" = "git/ignore";
  };
}
