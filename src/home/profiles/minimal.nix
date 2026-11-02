{ pkgs }:

# Daily tools, both editors, and the shared editor helpers.
with pkgs; [
  coreutils # Basic GNU utilities
  emacs-pgtk # Master of the universe editor
  fd # Modern find
  git-crypt # Encrypt git files
  libqalculate # CLI calculator
  httpie # Modern HTTP CLI client
  monaspace # Innovative font from githubnext
  nerd-fonts.symbols-only # Collection of icons / symbols
  rclone # File sync utility
  trashy # CLI trash handler
  # Provider runtimes belong to the editor wrapper, not the global PATH.
  (neovim.override {
    withNodeJs = true;
    withPython3 = true;
  })
] ++ import ./editor-helpers.nix { inherit pkgs; }
