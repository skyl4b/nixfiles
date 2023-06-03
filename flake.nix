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
          # Home-manager user and home path
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
          home.packages = with pkgs; [
            # Adds custom packages to the environment
            alejandra # Nix formatter
            bakoma_ttf # Latex fonts
            bat # Modern cat
            corefonts # Microsoft corefonts
            direnv # Directory specific environments
            docker # Container manager
            exa # Modern ls
            fzf # Fuzzy finder
            gcc # GNU C compiler
            git # Version control
            git-crypt # Encrypt git files
            helix # Editor
            hyfetch # Neofetch fork
            libcaca # Image-to-text utilities
            maple-mono-NF # Editor font
            neovim # Editor
            nil # Nix LSP
            nix-direnv # Direnv integration with nix
            nodePackages.bash-language-server # Bash LSP
            ranger # CLI file manager
            rclone # File sync utility
            ripgrep # Modern grep
            scanmem # Running process memory editor
            starship # Shell-agnostic customizable prompt
            tealdeer # Tldr man pages
            ttyper # Terminal monkeytype
            unicode-paracode # Unicode search tool
            vscode # Editor
            wl-clipboard # Wayland clipboard tool
            x11docker # GUI docker apps tool
            zathura # Pdf viewer with vi bindings
            zellij # Modern tmux
            zoxide # Cd with directory caching

            # # It is sometimes useful to fine-tune packages, for example, by applying
            # # overrides. You can do that directly here, just don't forget the
            # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
            # # fonts?
            # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

            # Simple shell scripts in the environment
            (writeShellScriptBin "update-home-manager" ''
              DIR=$(pwd)
              cd ~/.config/home-manager
              nix flake update && home-manager switch
              cd $DIR
            '')
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
