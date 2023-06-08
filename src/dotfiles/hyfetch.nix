{ pkgs, ... }: {
  enable = true;

  # Don't install hyfetch here, only configure it
  package = pkgs.runCommandLocal "no-hyfetch" { } "mkdir $out";
  # I prefer to have all packages in a single list

  # Set hyfetch config
  settings = {
    backend = "neofetch";
    color_align = {
      custom_colors = [ ];
      fore_back = null;
      mode = "horizontal";
    };
    light_dark = "dark";
    lightness = 0.65;
    mode = "rgb";
    preset = "rainbow";
    pride_month_disable = true; # Not reproducible with it enabled :(
  };
}
