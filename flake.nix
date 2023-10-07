{
  description = "Skylab's home-manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    bat-theme = {
      url = "github:catppuccin/bat";
      flake = false;
    };
    nnn = {
      url = "github:jarun/nnn";
      flake = false;
    };
    helix-git = {
      url = "github:skyl4b/helix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    copilot-lsp-src = {
      url = "github:github/copilot.vim";
      flake = false;
    };
    bottom-theme = {
      url = "github:catppuccin/bottom";
      flake = false;
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = import ./src/overlays inputs;
      };
      home-manager-path = "~/.config/home-manager";
      username = "skylab";
      hc = config:
        home-manager.lib.homeManagerConfiguration (config // {
          inherit pkgs;
          modules = [ inputs.agenix.homeManagerModules.default ]
            ++ config.modules;
        });
    in {
      homeConfigurations.${username} = hc {
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
            stateVersion = "23.11"; # Please read the comment before changing.

            # The home.packages option allows you to install Nix packages into your
            # environment.
            packages = with pkgs; [
              # Adds custom packages to the environment
              # (aspellWithDicts # Spell checking
              #   (ds: with ds; [ de en en-computers en-science fr pt_BR ]))
              agenix
              hunspell
              hunspellDicts.en_US-large
              hunspellDicts.de_DE
              hunspellDicts.fr-moderne
              hunspellDicts.pt_BR
              (hiPrio
                gcc) # GNU C compiler, priority to prevent a collision with clang
              bakoma_ttf # Latex fonts
              bat # Modern cat
              cachix # Nix binary caching
              cheat # Interactive CLI cheatsheets
              clang # LLVM C compiler
              corefonts # Microsoft corefonts
              coreutils # Basic GNU utilities
              direnv # Directory specific environments
              docker # Container manager
              exercism # Programming languages learning
              emacs-all-the-icons-fonts # Emacs icons
              emacs29-pgtk # Editor
              fd # Modern find
              fzf # Fuzzy finder
              gh # Github CLI tool
              git # Version control
              git-crypt # Encrypt git files
              git-extras # Useful extra commands for git
              gnuplot # CLI plotting tool
              # helix # Editor
              # hyfetch # Neofetch fork
              httpie # Modern HTTP CLI client
              lazydocker # Docker TUI
              languagetool # Spell-checking tool
              libcaca # Image-to-text utilities
              libertine # Linux libertine fonts
              maple-mono-NF # Editor font
              neovim # Editor
              nerdfonts # Fonts with symbols
              nix-direnv # Direnv integration with nix

              copilot-lsp # Custom copilot LSP
              nodePackages.bash-language-server # Bash LSP
              nodePackages.dockerfile-language-server-nodejs # Dockerfile LSP
              nodePackages.vscode-langservers-extracted # HTML / CSS / JSON / ESLint LSPs
              nodePackages.prettier # JS / TS / HTML / JSON / YAML code formatter
              marksman # Markdown LSP
              ltex-ls # Spell-checking LSP
              nil # Nix LSP
              nixfmt # Nix code formatter
              (python3.withPackages (ps:
                with ps; [
                  python-lsp-server # Python LSP
                  python-lsp-ruff # Python formatter
                  python-lsp-black # Python linter integration
                  pyls-isort # Python import formatter
                ]))
              ruff # Python linter
              taplo # TOML LSP
              nodePackages.yaml-language-server # YAML LSP
              clang-tools # C tools, includes LSP
              texlab # Latex / Bibtex LSP
              lldb # C / Rust Debugging
              typst-lsp # Typst LSP

              # ranger # CLI file manager
              rclone # File sync utility
              ripgrep # Modern grep
              scanmem # Running process memory editor
              shellcheck # Shell checker
              shfmt # Shell formatter
              starship # Shell-agnostic customizable prompt
              tealdeer # Tldr man pages
              thefuck # Corrects the last shell command
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
              (writeShellScriptBin "update" ''
                flatpak update
                home-manager-update
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
              EDITOR = "hx";
              VISUAL = "hx";
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
          programs = import ./src/dotfiles {
            inherit pkgs;
            inherit inputs;
          };
        }];
      };
    };
}
