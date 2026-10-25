let
  inputs = import ./flake-inputs.nix;
  system = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      ../modules/nixos/desktops/hyprland.nix
      {
        nixpkgs.hostPlatform = "x86_64-linux";
        boot.isContainer = true;
        system.stateVersion = "24.11";
      }
    ];
  };
in {
  # Neither reference host imports Hyprland; force its options and packages too.
  drvPath = system.config.system.build.toplevel.drvPath;
  warnings = system.config.warnings;
  qtTheme = system.config.qt.platformTheme;
  packages = map (package: package.name) system.config.environment.systemPackages;
}
