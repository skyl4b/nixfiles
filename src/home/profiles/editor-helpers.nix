{ pkgs }:

# Shared editor helpers stay global; projects supply their toolchains.
with pkgs; [
  hunspell
  hunspellDicts.en_US-large
  hunspellDicts.de_DE
  hunspellDicts.fr-moderne
  hunspellDicts.pt_BR
  languagetool # Spell-checking tool
  pyright # Python LSP
  bash-language-server # Bash LSP
  dockerfile-language-server # Dockerfile LSP
  vscode-langservers-extracted # HTML / CSS / JSON / ESLint LSPs
  typescript-language-server # TS / JS language server
  prettier # JS / TS / HTML / JSON / YAML code formatter
  markdownlint-cli # Markdown linter
  efm-langserver # Universal LSP (interacts with linters / formatters)
  prettierd # Prettier as a daemon
  marksman # Markdown LSP
  ltex-ls # Spell-checking LSP
  nil # Nix LSP
  statix # Nix linter
  nixpkgs-fmt # Nix formatter
  ruff # Python linter
  basedpyright # Modern python LSP
  taplo # TOML LSP
  yaml-language-server # YAML LSP
  clang-tools # C tools, includes LSP
  texlab # Latex / Bibtex LSP
  tinymist # Typst LSP
  lua-language-server # Lua LSP
  stylua # Lua formatter
  luajitPackages.luacheck # Lua linter
  docker-compose-language-service # Docker compose LSP
  hadolint # Dockerfile linter
  shellcheck # Shell checker
  shfmt # Shell formatter
  typos # Source code spell-checking tool
  typos-lsp # A LSP for spell-checking
  lemminx # XML LSP
  neocmakelsp # CMake LSP
  cmake-format # CMake linter / formatter
  commitlint # Linter for commit messages
]
