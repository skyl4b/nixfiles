{ testHome }:

let
  inputs = import ./flake-inputs.nix;
  pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
  cfg = (inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      ../modules/home/zellij.nix
      ../modules/home/hyfetch.nix
      ../modules/home/zathura.nix
      {
        home.username = "desktop-tools-test";
        home.homeDirectory = testHome;
        home.stateVersion = "23.11";
        xdg.enable = true;
        programs.bash.enable = true;
        programs.zsh.history.path = "${testHome}/.zsh_history";
      }
    ];
  }).config;
in {
  metadata = {
    inherit (cfg.dotfiles) anchor configFiles;
    packages = map (package: package.pname or package.name) cfg.home.packages;
    bashIntegration = cfg.programs.bash.initExtra;
    inherit (cfg.home) sessionVariables;
    fonts = "${pkgs.dejavu_fonts}/share/fonts/truetype";
  };
  files = cfg.home-files;
  runtime = pkgs.buildEnv {
    name = "nixfiles-desktop-tools-tests";
    paths = [
      pkgs.zellij pkgs.hyfetch pkgs.zathura pkgs.bash pkgs.coreutils
      pkgs.xorg-server pkgs.xdotool pkgs.dbus pkgs.dejavu_fonts
    ];
  };
}
