{ config, lib, pkgs, ... }:

{
  imports = [ ./live-dotfiles.nix ];

  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      path = "${config.xdg.stateHome}/zsh/history";
      size = 50000;
      save = 50000;
      share = true;
      ignoreAllDups = true;
      saveNoDups = true;
    };

    completionInit = ''
      mkdir -p -- "${config.xdg.cacheHome}/zsh"
      autoload -Uz compinit
      compinit -d "${config.xdg.cacheHome}/zsh/zcompdump-$ZSH_VERSION"
    '';
    # After completion setup and before syntax highlighting.
    initContent = lib.mkOrder 1000 ''
      source "${config.xdg.configHome}/zsh/config.zsh"
    '';
  };

  home.packages = [ pkgs.zsh-completions ];
  dotfiles.configFiles."zsh/config.zsh" = "zsh/config.zsh";
}
