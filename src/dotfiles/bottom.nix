{ ... }: {
  # Enable "bottom" a modern htop replacement
  enable = true;

  # Settings
  settings = {
    flags = {
      avg_cpu = true;
      temperature_type = "c";
    };

    colors = { low_battery_color = "red"; };
  };
}
