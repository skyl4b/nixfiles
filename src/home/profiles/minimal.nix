{ pkgs }:

# Daily tools, both editors, and the shared editor helpers.
with pkgs; [
  agenix
  cachix # Nix binary caching
  coreutils # Basic GNU utilities
  emacs-pgtk # Master of the universe editor
  fd # Modern find
  fzf # Fuzzy finder
  git-crypt # Encrypt git files
  libqalculate # CLI calculator
  httpie # Modern HTTP CLI client
  inetutils # Networking tools
  monaspace # Innovative font from githubnext
  nerd-fonts.symbols-only # Collection of icons / symbols
  rclone # File sync utility
  wl-clipboard # Wayland clipboard tool
  zoxide # Cd with directory caching
  trashy # CLI trash handler
  wget # File downloader
  just # Modern make
  # Provider runtimes belong to the editor wrapper, not the global PATH.
  (neovim.override {
    withNodeJs = true;
    withPython3 = true;
  })
] ++ import ./editor-helpers.nix { inherit pkgs; }
