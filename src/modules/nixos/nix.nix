{ ... }:

{
  nixpkgs.config.allowUnfree = true;
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      warn-dirty = false;
    };
    optimise.automatic = true;
  };

  # Combine age-based cleanup with a minimum fallback-generation count.
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep-since 7d --keep 2";
    };
  };
}
