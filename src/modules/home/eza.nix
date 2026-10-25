_: {
  programs.eza = {
    # Enable "eza" a modern ls replacement
    enable = true;

    # Show file's git status
    git = false;

    # Icons
    icons = "auto";

    # Extra CLI options
    extraOptions = [ "--group-directories-first" ];
  };
}
