{ ... }:

{
  imports = [ ./live-dotfiles.nix ];

  # Preserve shell hooks and the separately generated Nix-only library loader.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  dotfiles.configFiles = {
    "direnv/direnv.toml" = "direnv/direnv.toml";
    "direnv/direnvrc" = "direnv/direnvrc";
  };
}
