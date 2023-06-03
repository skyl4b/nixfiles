{
  description = "Home Manager configuration of skylab";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    home-manager,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    homeConfigurations."skylab" = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;

      modules = [
        {
          # Home Manager needs a bit of information about you and the paths it should
          # manage.
          home.username = "skylab";
          home.homeDirectory = "/home/skylab";

          # This value determines the Home Manager release that your configuration is
          # compatible with. This helps avoid breakage when a new Home Manager release
          # introduces backwards incompatible changes.
          #
          # You should not change this value, even if you update Home Manager. If you do
          # want to update the value, then make sure to first check the Home Manager
          # release notes.
          home.stateVersion = "23.05"; # Please read the comment before changing.

          # The home.packages option allows you to install Nix packages into your
          # environment.
          home.packages = [
            # Adds custom packages to the environment
            pkgs.alejandra # Nix formatter
            pkgs.bakoma_ttf # Latex fonts
            pkgs.bat # Modern cat
            pkgs.corefonts # Microsoft corefonts
            pkgs.direnv # Directory specific environments
            pkgs.docker # Container manager
            pkgs.exa # Modern ls
            pkgs.fzf # Fuzzy finder
            pkgs.gcc # GNU C compiler
            pkgs.git # Version control
            pkgs.git-crypt # Encrypt git files
            pkgs.helix # Editor
            pkgs.hyfetch # Neofetch fork
            pkgs.libcaca # Image-to-text utilities
            pkgs.maple-mono-NF # Editor font
            pkgs.neovim # Editor
            pkgs.nil # Nix LSP
            pkgs.nix-direnv # Direnv integration with nix
            pkgs.nodePackages.bash-language-server # Bash LSP
            pkgs.ranger # CLI file manager
            pkgs.rclone # File sync utility
            pkgs.ripgrep # Modern grep
            pkgs.scanmem # Running process memory editor
            pkgs.starship # Shell-agnostic customizable prompt
            pkgs.tealdeer # Tldr man pages
            pkgs.ttyper # Terminal monkeytype
            pkgs.unicode-paracode # Unicode search tool
            pkgs.vscode # Editor
            pkgs.wl-clipboard # Wayland clipboard tool
            pkgs.x11docker # GUI docker apps tool
            pkgs.zathura # Pdf viewer with vi bindings
            pkgs.zellij # Modern tmux
            pkgs.zoxide # Cd with directory caching

            # # It is sometimes useful to fine-tune packages, for example, by applying
            # # overrides. You can do that directly here, just don't forget the
            # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
            # # fonts?
            # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

            # # You can also create simple shell scripts directly inside your
            # # configuration. For example, this adds a command 'my-hello' to your
            # # environment:
            # (pkgs.writeShellScriptBin "my-hello" ''
            #   echo "Hello, ${config.home.username}!"
            # '')
          ];

          # Home Manager is pretty good at managing dotfiles. The primary way to manage
          # plain files is through 'home.file'.
          home.file = {
            # # Building this configuration will create a copy of 'dotfiles/screenrc' in
            # # the Nix store. Activating the configuration will then make '~/.screenrc' a
            # # symlink to the Nix store copy.
            # ".screenrc".source = dotfiles/screenrc;

            # # You can also set the file content immediately.
            # ".gradle/gradle.properties".text = ''
            #   org.gradle.console=verbose
            #   org.gradle.daemon.idletimeout=3600000
            # '';
          };

          # You can also manage environment variables but you will have to manually
          # source
          #
          #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
          #
          # or
          #
          #  /etc/profiles/per-user/skylab/etc/profile.d/hm-session-vars.sh
          #
          # if you don't want to manage your shell through Home Manager.
          home.sessionVariables = {
            # EDITOR = "emacs";
          };

          # Let Home Manager install and manage itself.
          programs.home-manager.enable = true;
        }
      ];
    };
  };
}
