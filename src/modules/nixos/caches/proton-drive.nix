{
  # Upstream CI publishes release builds against the Drive flake's own pin.
  nix.settings = {
    substituters = [ "https://proton-drive-linux.cachix.org" ];
    trusted-public-keys = [
      "proton-drive-linux.cachix.org-1:w1+3pXVXyTlqkFGn3dWpUhlaJtyGhSm3X0mFwfa++AA="
    ];
  };
}
