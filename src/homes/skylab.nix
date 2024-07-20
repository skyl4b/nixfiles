{ pkgs, username, inputs, home-manager-path, ... }: {
  imports = [
    inputs.catppuccin.homeManagerModules.catppuccin
  ];
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
      aichat # A chatbot in the terminal
      hunspell
      hunspellDicts.en_US-large
      hunspellDicts.de_DE
      hunspellDicts.fr-moderne
      hunspellDicts.pt_BR
      (hiPrio
        gcc) # GNU C compiler, priority to prevent a collision with clang
      bakoma_ttf # Latex fonts
      #bat # Modern cat
      cachix # Nix binary caching
      cheat # Interactive CLI cheatsheets
      clang # LLVM C compiler
      corefonts # Microsoft corefonts
      coreutils # Basic GNU utilities
      #direnv # Directory specific environments
      #docker # Container manager
      exercism # Programming languages learning
      (emacs29.override {
        withPgtk = true;
        withNativeCompilation = true;
      }) # Master of the universe editor
      fd # Modern find
      fzf # Fuzzy finder
      #git # Version control
      git-crypt # Encrypt git files
      git-extras # Useful extra commands for git
      gnuplot # CLI plotting tool
      libqalculate # CLI calculator
      httpie # Modern HTTP CLI client
      inetutils # Networking tools
      lazydocker # Docker TUI
      languagetool # Spell-checking tool
      libcaca # Image-to-text utilities
      libertine # Linux libertine fonts
      maple-mono # Apple-like font
      monaspace # Innovative font from githubnext
      (nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; }) # Fonts with symbols
      #nix-direnv # Direnv integration with nix

      nodePackages.bash-language-server # Bash LSP
      nodePackages.dockerfile-language-server-nodejs # Dockerfile LSP
      nodePackages.vscode-langservers-extracted # HTML / CSS / JSON / ESLint LSPs
      nodePackages.typescript-language-server # TS / JS language server
      nodePackages.prettier # JS / TS / HTML / JSON / YAML code formatter
      nodePackages.markdownlint-cli # Markdown linter
      nodePackages.live-server # A simple http server with auto reload
      efm-langserver # Universal LSP (interacts with linters / formatters)
      prettierd # Prettier as a daemon
      marksman # Markdown LSP
      ltex-ls # Spell-checking LSP
      nil # Nix LSP
      statix # Nix linter
      nixpkgs-fmt # Nix formatter
      # Python interactive environment
      (hiPrio (jupyter-all.withPackages (ps:
        with ps; [
          jupyter-console # Better python REPL
          jupytext # Jupyter notebook as .py scripts
          nbclient # A client library for executing notebooks
          debugpy # Python debug adapter protocol
          editorconfig # Editorconfig support
          grip # Markdown preview locally
          catppuccin # Pygments catppuccin theme
          # Broken, see: https://github.com/NixOS/nixpkgs/issues/255262
          # orange3 # Data visualization tool
        ])))
      # Jupyter & markdown publishing
      (quarto.override {
        python3 = null;
        rWrapper = null;
      })
      ruff # Python linter
      basedpyright # Modern python LSP
      taplo # TOML LSP
      nodePackages.yaml-language-server # YAML LSP
      clang-tools # C tools, includes LSP
      texlab # Latex / Bibtex LSP
      lldb # C / Rust Debugging
      typst-lsp # Typst LSP
      lua-language-server # Lua LSP
      stylua # Lua formatter
      luajitPackages.luacheck # Lua linter
      docker-compose-language-service # Docker compose LSP
      hadolint # Dockerfile linter
      ollama # Run LLMs locally
      # Rust toolchain
      (rust-bin.stable.latest.default.override {
        extensions = [ "rust-src" "rust-analyzer-preview" "llvm-tools-preview" ];
        targets = [ "x86_64-unknown-linux-gnu" "wasm32-unknown-unknown" ];
      })
      dioxus-cli # Rust web framework
      llvmPackages.bintools # LLVM linker
      monocraft # Minecraft-like font
      rclone # File sync utility
      scanmem # Running process memory editor
      shellcheck # Shell checker
      shfmt # Shell formatter
      bashdb # Bash debugger
      #starship # Shell-agnostic customizable prompt
      hyperfine # CLI benchmarking tool
      parallel-full # CLI parallelize command tool
      #tealdeer # Tldr man pages
      thefuck # Corrects the last shell command
      ttyper # Terminal monkeytype
      unicode-paracode # Unicode search tool
      vscode # Editor
      w3m # Terminal web browser
      wl-clipboard # Wayland clipboard tool
      x11docker # GUI docker apps tool
      xdg-ninja # XDG cli helper
      #zathura # Pdf viewer with vi bindings
      #zellij # Modern tmux
      zoxide # Cd with directory caching
      trashy # CLI trash handler
      grex # RegEx builder
      gdb # GNU debugger
      gnumake # GNU builder
      wget # File downloader
      typescript # Js superset with type checks
      bun # Fast js runtime / bundler
      gleam # A friendly language for type-safe systems
      erlang # Scalable real-time language (used by gleam)
      rebar3 # Erlang build tool
      typos # Source code spell-checking tool
      typos-lsp # A LSP for spell-checking
      inshellisense # IDE-style cli autocomplete
      devcontainer # CLI to handle dev environments
      just # Modern make
      lemminx # XML LSP
      neocmakelsp # CMake LSP
      cmake-format # CMake linter / formatter
      commitlint # Linter for commit messages
      zed-editor # Rust based GUI editor

      # Mesa drivers wrapper for GUI apps on non
      # NixOS hosts
      #nixgl.nixGLIntel

      # Wrap my own neovim
      # Copy the standard runtime to $XDG_DATA_HOME/nvim/runtime
      # and alias VIMRUNTIME to it
      (neovim-unwrapped.override {
        nodejs = true;
        python3 = true;
      })
      tree-sitter
      nodejs
      deno

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
    sessionVariables = rec {
      HOME_MANAGER_PATH = home-manager-path;
      EDITOR = "nvim";
      VISUAL = EDITOR;
    };

    # Custom directories added to PATH in the environment
    sessionPath = [ "$HOME/.local/bin" ];

    # Shell aliases in the environment
    shellAliases = [ ];
  };

  # XDG user directories management
  xdg = {
    enable = true;

    # Commitlint global configuration
    configFile."commitlint/commitlint.config.js".text = ''
      export default { extends: ['@commitlint/config-conventional'] };
    '';
  };

  # Enable fontconfig for installed nix fonts,
  # so that they're automatically available to applications
  fonts.fontconfig.enable = true;

  # Program configuration in the environment
  programs = import ../dotfiles {
    inherit pkgs;
    inherit inputs;
  };
}
