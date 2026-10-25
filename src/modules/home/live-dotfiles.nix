{ config, lib, ... }:

let
  cfg = config.dotfiles;
  relativePath = value:
    value != "" && !lib.hasPrefix "/" value
    && lib.all (part: part != "..") (lib.splitString "/" value);
in
{
  options.dotfiles = {
    anchor = lib.mkOption {
      type = lib.types.addCheck lib.types.str (value:
        lib.hasPrefix "/" value && value != builtins.storeDir
        && !lib.hasPrefix "${builtins.storeDir}/" value);
      default = "${config.xdg.dataHome}/nixfiles";
      defaultText = lib.literalExpression ''config.xdg.dataHome + "/nixfiles"'';
      description = "Absolute user-local symlink to the current checkout, outside the Nix store.";
    };

    configFiles = lib.mkOption {
      type = lib.types.attrsOf (lib.types.addCheck lib.types.str relativePath);
      default = { };
      example = { "git/config" = "git/config"; };
      description = "XDG config targets mapped to paths relative to src/dotfiles in the checkout.";
    };
  };

  config = {
    xdg.configFile = lib.mapAttrs (_: source: {
      source = config.lib.file.mkOutOfStoreSymlink
        "${cfg.anchor}/src/dotfiles/${source}";
    }) cfg.configFiles;
  };
}
