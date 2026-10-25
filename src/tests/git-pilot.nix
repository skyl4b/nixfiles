{ testHome, anchor ? null }:

let
  inputs = import ./flake-inputs.nix;
  lib = inputs.nixpkgs.lib;
  home = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
    modules = [
      ../modules/home/git.nix
      {
        home.username = "git-pilot";
        home.homeDirectory = testHome;
        home.stateVersion = "23.11";
        xdg.enable = true;
      }
    ] ++ lib.optional (anchor != null) { dotfiles.anchor = anchor; };
  };
  cfg = home.config;
in
{
  metadata = {
    inherit (cfg.dotfiles) anchor configFiles;
    generatedGit = cfg.programs.git.enable;
    configText = cfg.xdg.configFile."git/config".text;
    ignoreText = cfg.xdg.configFile."git/ignore".text;
    packages = map (package: package.pname or package.name) cfg.home.packages;
  };

  files = cfg.home-files;
}
