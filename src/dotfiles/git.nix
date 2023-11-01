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
      tool = "nvimdiff";
      guitool = "nvimdiff";
    };
    diff = {
      tool = "nvimdiff";
      guitool = "nvimdiff";
    };
  };
}
