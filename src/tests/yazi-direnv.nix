{ testHome, anchor ? null }:

let
  inputs = import ./flake-inputs.nix;
  lib = inputs.nixpkgs.lib;
  pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
  home = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      ../modules/home/yazi.nix
      ../modules/home/direnv.nix
      {
        home.username = "yazi-direnv-test";
        home.homeDirectory = testHome;
        home.stateVersion = "23.11";
        xdg.enable = true;
        programs.bash.enable = true;
        programs.zsh.enable = true;
        programs.zsh.dotDir = testHome;
        programs.zsh.history.path = "${testHome}/.zsh_history";
      }
    ] ++ lib.optional (anchor != null) { dotfiles.anchor = anchor; };
  };
  cfg = home.config;
in
{
  metadata = {
    inherit (cfg.dotfiles) anchor configFiles;
    generated = {
      inherit (cfg.programs.yazi) settings keymap theme plugins;
      direnvConfig = cfg.programs.direnv.config;
      direnvStdlib = cfg.programs.direnv.stdlib;
    };
    packages = map (package: package.pname or package.name) cfg.home.packages;
    bashIntegration = cfg.programs.bash.initExtra;
    zshIntegration = cfg.programs.zsh.initContent;
    nixDirenvSource = toString cfg.xdg.configFile."direnv/lib/hm-nix-direnv.sh".source;
  };

  files = cfg.home-files;

  runtime = pkgs.buildEnv {
    name = "nixfiles-yazi-direnv-tests";
    paths = [ pkgs.yazi pkgs.direnv pkgs.bash pkgs.coreutils ];
  };
}
