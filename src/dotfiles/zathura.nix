{ ... }: {
  # Zathura setup
  enable = true;

  # Options
  options = {
    highlight-transparency = "0.05";
    selection-clipboard = "clipboard";
  };

  # Mappings
  mappings = {
    "<C-d>" = "navigate next";
    "<C-u>" = "navigate previous";
  };
}