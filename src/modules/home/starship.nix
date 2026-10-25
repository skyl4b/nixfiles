{ ... }:

{
  imports = [ ./live-dotfiles.nix ];

  # Keep package, STARSHIP_CONFIG, and shell hooks from Home Manager.
  programs.starship.enable = true;
  dotfiles.configFiles."starship.toml" = "starship/starship.toml";
}
