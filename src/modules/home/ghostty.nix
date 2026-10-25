{ pkgs, ... }:

{
  imports = [ ./live-dotfiles.nix ];

  programs.ghostty = {
    enable = true;
    # Keep bat's configuration owned by its shared native file.
    installBatSyntax = false;
  };
  home.packages = [ pkgs.cascadia-code ];
  dotfiles.configFiles."ghostty/config" = "ghostty/config";
}
