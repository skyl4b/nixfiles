{ testHome }:

let
  inputs = import ./flake-inputs.nix;
  pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
  cfg = (inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      ../modules/home/zsh.nix
      ../modules/home/starship.nix
      ../modules/home/direnv.nix
      ../modules/home/eza.nix
      ../modules/home/fzf.nix
      ../modules/home/zoxide.nix
      {
        home.username = "zsh-test";
        home.homeDirectory = testHome;
        home.stateVersion = "23.11";
        xdg.enable = true;
      }
    ];
  }).config;
in
{
  files = cfg.home-files;
  runtime = pkgs.buildEnv {
    name = "nixfiles-zsh-tests";
    paths = [ cfg.home.path (pkgs.python3.withPackages (ps: [ ps.pexpect ])) ];
    pathsToLink = [ "/bin" "/share/zsh" ];
  };
}
