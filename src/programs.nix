{ inputs }:

let
  # Dotfiles loader
  dotfiles = builtins.readDir ./dotfiles;

  # Import each program's configuration into a map
  configs = builtins.listToAttrs (builtins.map (program: {
    name = inputs.pkgs.lib.removeSuffix ".nix" (baseNameOf program);
    value = import ./dotfiles/${program} { inherit inputs; };
  }) (builtins.attrNames dotfiles));
in configs
