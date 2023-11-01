{ ... }: {
  enable = true;

  # Git profile
  userName = "Eduardo Farinati";
  userEmail = "eduardo.farinati@ufrgs.br";

  # Git aliases
  aliases = { };

  # Globally ignored paths
  ignores = [ "*.swp" ".bin" ".envrc" ".direnv" ];

  # Extra configs
  extraConfig = {
    merge = {
      # Set mergetool
      tool = "nvimdiff";
      guitool = "nvimdiff";
      # Clean up backup / temp files on exit
      keepBackup = false;
      keepTemporaries = false;
    };

    diff = {
      # Set difftool
      tool = "nvimdiff";
      guitool = "nvimdiff";
      # Use mnemonic prefixes instead of a/ b/
      # ie: i - index, w - worktree, c - commit, o - object
      mnemonicPrefix = true;
      # Enable rename detection
      rename = true;
    };

    color = {
      # Color output if possible
      ui = "auto";
      # Use cyan as color for upstream in git branch -vv
      upstream = "cyan";
    };

    # Enable line numbers in grep
    grep.lineNumber = true;

    log = {
      # Abbreviate commit sha when possible
      abbrevCommit = true;

      # Follow history through renames for
      # single files
      follow = true;
    };

    push = {
      # Push to tracking remote, regardless of branch name
      # NOTE: prefer using the same name when possible
      default = "upstream";
      # Push tags together by default
      followTags = true;
      # Setup branch on remote if no tracking branch is set
      autoSetupRemote = true;
    };

    # Sort tags version numbers when applicable
    tag.sort = "version:refname";

    # Define the version sorting strategy
    versionsort.suffix = [
      "-pre"
      ".pre"
      "-beta"
      ".beta"
      "-rc"
      ".rc"
    ];
  };
}
