{ inputs }:

let
  # Dotfiles loader
  dotfiles = builtins.readDir ./dotfiles;

  # Filter to config paths inside directories or ".nix" files
  configPaths = builtins.mapAttrs (name: type:
    if type == "directory" then
      ./. + "/dotfiles/${name}/config.nix"
    else if inputs.pkgs.lib.hasSuffix ".nix" name then
      ./. + "/dotfiles/${name}"
    else
      null) dotfiles;

  # Import each program's configuration into a map
  configs = builtins.listToAttrs (builtins.map (config: {
    name = inputs.pkgs.lib.removeSuffix ".nix" (baseNameOf config);
    value = import configPaths.${config} { inherit inputs; };
  }) (builtins.filter (config: configPaths.${config} != null)
    (builtins.attrNames configPaths)));
in configs // {
  # Extra configs

  # Let Home Manager install and manage itself
  home-manager.enable = true;
}
