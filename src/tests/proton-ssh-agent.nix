{ testHome }:

let
  inputs = import ./flake-inputs.nix;
  pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
  cfg = (inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    extraSpecialArgs = { inherit inputs; };
    modules = [
      ../modules/home/proton.nix
      {
        home.username = "proton-agent-test";
        home.homeDirectory = testHome;
        home.stateVersion = "23.11";
        xdg.enable = true;
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
  # Test the real Proton module without building Drive's unrelated unit files.
  files = pkgs.linkFarm "nixfiles-proton-agent-files" (map (name: {
    inherit name;
    path = cfg.home.file.${name}.source;
  }) [
    ".zshenv"
    ".config/zsh/.zshenv"
    ".config/zsh/.zprofile"
  ] ++ map (name: {
    name = ".config/${name}";
    path = cfg.xdg.configFile.${name}.source;
  }) [
    "environment.d/10-home-manager.conf"
    "systemd/user/proton-pass-agent.service"
    "systemd/user/set-SSH_AUTH_SOCK.service"
    "systemd/user/gcr-ssh-agent.service"
    "systemd/user/gcr-ssh-agent.socket"
  ]);
  runtime = pkgs.buildEnv {
    name = "nixfiles-proton-agent-tests";
    paths = [ pkgs.proton-pass-cli pkgs.zsh pkgs.systemd pkgs.python3 ];
  };
  # Nixpkgs keeps upstream units here for NixOS to compose into /etc/systemd.
  systemdUnits = "${pkgs.systemd}/example/systemd/user";
}
