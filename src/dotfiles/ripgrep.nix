{ ... }: {
  # Enable ripgrep a modern replacement for grep
  enable = true;

  # Arguments to pass by default to ripgrep
  arguments = [
    # Ignore casing if no uppercase letters
    # are provided in the pattern
    "--smart-case"
  ];
}
