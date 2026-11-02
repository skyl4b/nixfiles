{ testHome }:

let
  inputs = import ./flake-inputs.nix;
  pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
  cfg = (inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      ../modules/home/proton-ssh-agent.nix
      {
        home.username = "proton-agent-test";
        home.homeDirectory = testHome;
        home.stateVersion = "23.11";
        xdg.enable = true;
        # The parent Proton module supplies this to the user manager in NixOS.
        systemd.user.sessionVariables.PROTON_PASS_LINUX_KEYRING = "dbus";
        programs.zsh = {
          enable = true;
          dotDir = "${testHome}/.config/zsh";
          history.path = "${testHome}/.local/state/zsh/history";
        };
      }
    ];
  }).config;
in
{
  files = cfg.home-files;
  sessionVariables = cfg.home.sessionVariablesPackage;
  runtime = pkgs.buildEnv {
    name = "nixfiles-proton-agent-tests";
    paths = [ pkgs.proton-pass-cli pkgs.zsh pkgs.bash pkgs.systemd pkgs.python3 ];
  };
  # Nixpkgs keeps upstream units here for NixOS to compose into /etc/systemd.
  systemdUnits = "${pkgs.systemd}/example/systemd/user";
}
