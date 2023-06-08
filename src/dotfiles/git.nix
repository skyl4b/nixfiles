{ ... }: {
  enable = true;

  # Git profile
  userName = "Eduardo Farinati";
  userEmail = "eduardo.farinati@ufrgs.br";

  # Git aliases
  aliases = {
    root = "rev-parse --show-toplevel";
  };

  # Globally ignored paths
  ignores = [
    "*.swp"
    ".bin"
    ".envrc"
    ".direnv"
  ];
}
