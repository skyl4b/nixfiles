{
  description = "Skylab's home-manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    bat-theme = {
      url =
        "https://raw.githubusercontent.com/catppuccin/bat/master/Catppuccin-mocha.tmTheme";
      flake = false;
    };
    nnn = {
      url = "github:jarun/nnn";
      flake = false;
    };
  };

  outputs = { nixpkgs, home-manager, bat-theme, nnn, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      extras = {
        inherit bat-theme;
        nnn-plugins = nnn + "/plugins";
      };
      home-manager-path = "~/.config/home-manager";
      username = "skylab";
    in {
      homeConfigurations.${username} =
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          modules = [{
            home = {
              # Home-manager user and home path
              inherit username;
              homeDirectory = "/home/${username}";

              # This value determines the Home Manager release that your configuration is
              # compatible with. This helps avoid breakage when a new Home Manager release
              # introduces backwards incompatible changes.
              #
              # You should not change this value, even if you update Home Manager. If you do
              # want to update the value, then make sure to first check the Home Manager
              # release notes.
              stateVersion = "23.05"; # Please read the comment before changing.

              # The home.packages option allows you to install Nix packages into your
              # environment.
              packages = with pkgs; [
                # Adds custom packages to the environment
                (aspellWithDicts # Spell checking
                  (ds: with ds; [ de en en-computers en-science fr pt_BR ]))
                (hiPrio
                  gcc) # GNU C compiler, priority to prevent a collision with clang
                bakoma_ttf # Latex fonts
                bat # Modern cat
                clang # LLVM C compiler
                corefonts # Microsoft corefonts
                coreutils # Basic GNU utilities
                direnv # Directory specific environments
                docker # Container manager
                emacs-all-the-icons-fonts # Emacs icons
                emacs29-pgtk # Editor
                exa # Modern ls
                fd # Modern find
                fzf # Fuzzy finder
                gh # Github CLI tool
                git # Version control
                git-crypt # Encrypt git files
                gnuplot # CLI plotting tool
                helix # Editor
                hyfetch # Neofetch fork
                lazydocker # Docker TUI
                libcaca # Image-to-text utilities
                libertine # Linux libertine fonts
                maple-mono-NF # Editor font
                neovim # Editor
                nerdfonts # Fonts with symbols
                nil # Nix LSP
                nix-direnv # Direnv integration with nix
                nixfmt # Nix code formatter
                nodejs # Javascript for LSPs
                ranger # CLI file manager
                rclone # File sync utility
                ripgrep # Modern grep
                scanmem # Running process memory editor
                shellcheck # Shell checker
                shfmt # Shell formatter
                starship # Shell-agnostic customizable prompt
                tealdeer # Tldr man pages
                ttyper # Terminal monkeytype
                unicode-paracode # Unicode search tool
                vscode # Editor
                w3m # Terminal web browser
                wl-clipboard # Wayland clipboard tool
                x11docker # GUI docker apps tool
                xdg-ninja # Xdg cli helper
                zathura # Pdf viewer with vi bindings
                zellij # Modern tmux
                zoxide # Cd with directory caching

                # # It is sometimes useful to fine-tune packages, for example, by applying
                # # overrides. You can do that directly here, just don't forget the
                # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
                # # fonts?
                # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

                # Simple shell scripts in the environment
                (writeShellScriptBin "home-manager-update" ''
                  DIR=$(pwd)
                  cd ${home-manager-path}
                  nix flake update && home-manager switch
                  cd $DIR
                '')
              ];

              # Home Manager is pretty good at managing dotfiles. The primary way to manage
              # plain files is through 'home.file'.
              file = {
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
              sessionVariables = {
                HOME_MANAGER_PATH = home-manager-path;
                # EDITOR = "emacs";
              };

              # Custom directories added to PATH in the environment
              sessionPath = [ "$HOME/.local/bin" ];

              # Shell aliases in the environment
              shellAliases = [ ];
            };

            # Enable fontconfig for installed nix fonts,
            # so that they're automatically available to applications
            fonts.fontconfig.enable = true;

            # Program configuration in the environment
            programs = import src/programs.nix {
              inherit pkgs;
              inherit extras;
            };
          }];
        };
    };
}
