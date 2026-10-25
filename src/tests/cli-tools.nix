{ testHome }:

let
  inputs = import ./flake-inputs.nix;
  pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
  home = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      ../modules/home/bat.nix
      ../modules/home/bottom.nix
      ../modules/home/ripgrep.nix
      ../modules/home/tealdeer.nix
      {
        home.username = "cli-tools-test";
        home.homeDirectory = testHome;
        home.stateVersion = "23.11";
        xdg.enable = true;
      }
    ];
  };
  cfg = home.config;
in {
  metadata = {
    inherit (cfg.dotfiles) anchor configFiles;
    packages = map (package: package.pname or package.name) cfg.home.packages;
    ripgrepConfig = cfg.home.sessionVariables.RIPGREP_CONFIG_PATH;
    batCache = cfg.home.activation.batCache.data;
    updateTimer = cfg.systemd.user.timers.tldr-update;
  };
  files = cfg.home-files;
  runtime = pkgs.buildEnv {
    name = "nixfiles-cli-tools-tests";
    paths = [ pkgs.bat pkgs.bottom pkgs.ripgrep pkgs.tealdeer pkgs.bash pkgs.coreutils ];
  };
}
