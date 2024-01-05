{ pkgs, ... }: {
  enable = true;

  # Don't install wezterm, only configure it
  #package = pkgs.runCommandLocal "no-wezterm" { } "mkdir $out";
  # Installing it is a bit of a pain because o GPU acceleration
  # so it is better to use the flatpak, in my opinion

  # Set wezterm config
  extraConfig = builtins.readFile ./wezterm.lua;
}
