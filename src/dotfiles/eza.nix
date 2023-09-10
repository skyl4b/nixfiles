{ ... }: {
  # Enable "eza" a modern ls replacement
  enable = true;

  # Aliases
  enableAliases = true;

  # Show file's git status
  git = false;

  # Icons
  icons = true;

  # Extra CLI options
  extraOptions = [ "--group-directories-first" ];
}
