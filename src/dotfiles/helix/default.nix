{ pkgs, inputs, ... }: {
  # Helix setup
  enable = true;

  # Set helix git package
  package = inputs.helix-git.packages.${pkgs.system}.default;

  # Language specific configuration
  languages = import ./languages.nix inputs.helix-git;

  # General settings
  settings = import ./settings.nix;

  # Custom theme
  themes.catppuccin_transparent = {
    inherits = "catppuccin_mocha";
    "ui.background" = { };
  };
}
