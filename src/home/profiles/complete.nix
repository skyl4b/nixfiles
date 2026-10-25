{ pkgs }:

# Add specialized tools to the minimal profile.
(import ./minimal.nix { inherit pkgs; }) ++ (with pkgs; [
  aichat # A chatbot in the terminal
  bakoma_ttf # Latex fonts
  cheat # Interactive CLI cheatsheets
  corefonts # Microsoft corefonts
  distrobox # System integrated containers
  exercism # Programming languages learning
  git-extras # Useful extra commands for git
  gnuplot # CLI plotting tool
  lazydocker # Docker TUI
  libcaca # Image-to-text utilities
  libertine # Linux libertine fonts
  # Publishing frontend; projects supply Python/R engines.
  (quarto.override {
    python3 = null;
    rWrapper = null;
  })
  ollama # Run LLMs locally
  monocraft # Minecraft-like font
  scanmem # Running process memory editor
  hyperfine # CLI benchmarking tool
  parallel-full # CLI parallelize command tool
  ttyper # Terminal monkeytype
  unicode-paracode # Unicode search tool
  w3m # Terminal web browser
  x11docker # GUI docker apps tool
  xdg-ninja # XDG cli helper
  grex # RegEx builder
  inshellisense # IDE-style cli autocomplete
  devcontainer # CLI to handle dev environments
])
