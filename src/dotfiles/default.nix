{ inputs }:

let
  # Dotfiles loader
  dotfiles = builtins.readDir ./.;

  # Import each program's configuration into a map
  configs = builtins.listToAttrs (builtins.map (program: {
    name = inputs.pkgs.lib.removeSuffix ".nix" (baseNameOf program);
    value = import ./${program} { inherit inputs; };
  }) (builtins.filter (program: program != "default.nix")
    (builtins.attrNames dotfiles)));
in configs
