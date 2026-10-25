{ pkgs, ... }:

{
  virtualisation.waydroid = {
    enable = true;
    # Avoid Waydroid's legacy iptables preference on current kernels.
    package = pkgs.waydroid-nftables;
  };
}
