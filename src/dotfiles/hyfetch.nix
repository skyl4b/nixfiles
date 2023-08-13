{ ... }: {
  enable = true;

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
    pride_month_disable = true; # Build is not reproducible with it enabled :(
  };
}
