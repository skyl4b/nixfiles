{
  # Direnv setup
  enable = true;
  nix-direnv.enable = true;
  config = {
    global = {
      strict_env = true;
      warn_timeout = "1h";
    };
  };

  # Store .envrc files outside of project directories.
  stdlib = builtins.readFile ./direnvrc;
}
