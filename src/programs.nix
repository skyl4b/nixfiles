{ pkgs, ... }:

let
  # List dotfiles, filtering out files that don't end with ".nix"
  dotfiles = builtins.filter (file: pkgs.lib.hasSuffix ".nix" file)
    (map (file: toString file)
      (pkgs.lib.filesystem.listFilesRecursive ./dotfiles));

  # Import each program's configuration and convert it
  # to a single map
  configs = builtins.listToAttrs (builtins.map (file: {
    name = pkgs.lib.removeSuffix ".nix" (baseNameOf file);
    value = import file { inherit pkgs; };
  }) dotfiles);
in configs // {
  # Extra configs

  # Let Home Manager install and manage itself
  home-manager.enable = true;
}
