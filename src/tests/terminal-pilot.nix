{ testHome, anchor ? null }:

let
  inputs = import ./flake-inputs.nix;
  lib = inputs.nixpkgs.lib;
  pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
  home = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      ../modules/home/tmux.nix
      ../modules/home/ghostty.nix
      {
        home.username = "terminal-pilot";
        home.homeDirectory = testHome;
        home.stateVersion = "23.11";
        xdg.enable = true;
        programs.bash.enable = true;
        programs.zsh.enable = true;
        programs.zsh.dotDir = testHome;
        programs.zsh.history.path = "${testHome}/.zsh_history";
      }
    ] ++ lib.optional (anchor != null) { dotfiles.anchor = anchor; };
  };
  cfg = home.config;
in
{
  metadata = {
    inherit (cfg.dotfiles) anchor configFiles;
    tmuxText = cfg.xdg.configFile."tmux/tmux.conf".text;
    ghosttyText = cfg.xdg.configFile."ghostty/config".text;
    ghosttySettings = cfg.programs.ghostty.settings;
    fontDirectory = "${pkgs.cascadia-code}/share/fonts";
    generatedTmux = cfg.programs.tmux.enable;
    inherit (cfg.home) sessionVariables;
    packages = map (package: package.pname or package.name) cfg.home.packages;
    ghosttyShellIntegration = {
      bash = cfg.programs.bash.initExtra;
      zsh = cfg.programs.zsh.initContent;
    };
    plugins = {
      catppuccin = toString cfg.xdg.configFile."tmux/plugins/catppuccin".source;
      resurrect = toString cfg.xdg.configFile."tmux/plugins/resurrect".source;
    };
  };

  files = cfg.home-files;

  # Test executables only; repository development dependencies remain in Pixi.
  runtime = pkgs.buildEnv {
    name = "nixfiles-terminal-tests";
    paths = [ pkgs.tmux pkgs.ghostty pkgs.cascadia-code pkgs.fontconfig pkgs.bash pkgs.coreutils pkgs.gnugrep pkgs.procps ];
  };
}
