{ testHome, anchor ? null }:

let
  inputs = import ./flake-inputs.nix;
  lib = inputs.nixpkgs.lib;
  pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
  home = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      ../modules/home/starship.nix
      ../modules/home/gitui.nix
      {
        home.username = "starship-gitui-test";
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
    starshipSettings = cfg.programs.starship.settings;
    starshipConfig = cfg.home.sessionVariables.STARSHIP_CONFIG;
    gituiEnabled = cfg.programs.gitui.enable;
    packages = map (package: package.pname or package.name) cfg.home.packages;
    bashIntegration = cfg.programs.bash.initExtra;
    zshIntegration = cfg.programs.zsh.initContent;
  };
  files = cfg.home-files;
  runtime = pkgs.buildEnv {
    name = "nixfiles-starship-gitui-tests";
    paths = [ pkgs.starship pkgs.gitui pkgs.git pkgs.bash pkgs.coreutils ];
  };
}
