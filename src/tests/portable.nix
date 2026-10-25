{ testHome }:

let
  inputs = import ./flake-inputs.nix;
  pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
  home = (inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      ../modules/home
      {
        home.username = "portable-test";
        home.homeDirectory = testHome;
        home.stateVersion = "23.11";
        xdg.enable = true;
      }
    ];
  }).config;
  fixtures = map (name: import (./. + "/${name}.nix") { inherit testHome; }) [
    "terminal-pilot"
    "yazi-direnv"
    "starship-gitui"
    "cli-tools"
    "desktop-tools"
  ];
in {
  # Compare chezmoi's complete link tree with the same modules used on NixOS.
  metadata = {
    configFiles = home.dotfiles.configFiles;
    fonts = "${pkgs.dejavu_fonts}/share/fonts/truetype";
  };
  # Reuse existing application fixtures; no Home Manager generation is built.
  runtime = pkgs.buildEnv {
    name = "nixfiles-portable-tests";
    paths = map (fixture: fixture.runtime) fixtures ++ [ pkgs.commitlint ];
    pathsToLink = [ "/bin" ];
  };
}
