{ inputs, ... }: {
  # Enable "bottom" a modern htop replacement
  enable = true;

  # Settings
  settings = {
    flags = {
      # Update rate of the app
      rate = "750ms";
      # Process searching case sensitive
      case_sensitive = true;
      # Process searching with regex
      regex = true;
      # Celsius as temperature unit
      temperature_type = "celsius";
      # Show GPU(s) memory
      enable_gpu_memory = true;
      # Show cache and buffer memory
      enable_cache_memory = true;
    };

    colors = builtins.fromTOML
      (builtins.readFile (inputs.bottom-theme + /themes/mocha.toml));
  };
}
