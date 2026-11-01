{ testHome }:

let
  inputs = import ./flake-inputs.nix;
  pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
  cfg = (inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      ../modules/home/doom.nix
      {
        home.username = "doom-test";
        home.homeDirectory = testHome;
        home.stateVersion = "23.11";
        xdg.enable = true;
      }
    ];
  }).config;
in
{
  metadata = {
    inherit (cfg.dotfiles) anchor configFiles;
    generatedEmacs = cfg.programs.emacs.enable;
    sources = builtins.mapAttrs (_: file: toString file.source) cfg.xdg.configFile;
  };
  files = cfg.home-files;
  emacs = pkgs.emacs-nox;
}
