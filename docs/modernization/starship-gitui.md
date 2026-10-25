# Native Starship and gitui configuration

Starship and gitui now share native files between Home Manager and chezmoi,
continuing NIX-8. The original generated files were captured before extraction
to compare settings, palettes, and bindings.

## Sources and ownership

| Canonical source | XDG target |
| --- | --- |
| `src/dotfiles/starship/starship.toml` | `starship.toml` |
| `src/dotfiles/gitui/key_bindings.ron` | `gitui/key_bindings.ron` |
| `src/dotfiles/gitui/theme.ron` | `gitui/theme.ron` |
| `src/dotfiles/gitui/LICENSE-catppuccin` | `gitui/LICENSE-catppuccin` |

The modules in `src/modules/home/` map these four targets through the common
checkout anchor. Chezmoi adapters under `src/chezmoi/dot_config/` link to the same
sources. Refresh the Home Manager anchor after moving the checkout, or reapply
chezmoi with its new source path. The configs contain no Nix store paths.

The pinned Starship module generates its file only when `settings` is nonempty.
It stays enabled with empty settings, preserving the package, shell integration,
and `STARSHIP_CONFIG` variable. Catppuccin integration is left disabled, and
`configPath` uses the standard XDG file owned by the live link.

The pinned gitui module generates both RON files whenever enabled. The native
module installs `programs.gitui.package` directly, leaving
`programs.gitui.enable` and `catppuccin.gitui.enable` disabled. Package
overrides remain available through the package option. Chezmoi deploys files;
applications and shell hooks must be supplied by the destination operating
system when using it.

## Preserved settings and corrections

The Starship TOML includes the existing Mocha palette, ten-millisecond scan
timeout, lambda character, directory style, module symbols/formats, and enabled
or disabled modules. Both gitui RON files are byte-identical to their former
generated versions, retaining the vim-style bindings and Mocha theme.

Runtime validation found two pre-existing Starship issues during extraction:

- The bare `env_var.format` entry had no variable configured and failed the
  pinned application's computed-config deserialization. It is removed. Named
  environment-variable modules can be configured in `[env_var.NAME]` blocks.
- Nix had consumed backslashes meant to escape literal characters in nine
  format strings. Native TOML literal strings retain those escapes for AWS,
  container, Elixir, Google Cloud, Kubernetes, memory usage, OCaml, OpenStack,
  and Python. For example, AWS now renders a literal `(us-east-1)` and container
  names retain their brackets.

After accounting for those corrections, the parsed Starship settings match the
previous generated file exactly. Starship documents its
[format strings and environment-variable configuration](https://starship.rs/config/).
The actual pinned Starship 1.24.1 was used to verify the correction.

The gitui theme comes from the existing pinned Catppuccin gitui source at
[revision df2f59f847e047ff119a105afff49238311b2d36](https://github.com/catppuccin/gitui/tree/df2f59f847e047ff119a105afff49238311b2d36),
dated 2025-02-22. Its MIT license is stored and deployed alongside the RON files.
The native palette/theme is now versioned with the repository; a future Nix input
update does not automatically replace these native settings.

## Verification

```sh
pixi run --locked check
NIXFILES_TEST_ROOT=/absolute/path/to/writable/scratch pixi run --locked test-starship-gitui-nix
NIXFILES_TEST_ROOT=/absolute/path/to/writable/scratch pixi run --locked baseline
```

`check` includes `test-starship-gitui`, covering chezmoi links, native TOML parsing,
live editing, and relocation of a temporary checkout whose path contains spaces.
RON parsing is checked by the real gitui runtime.

`test-starship-gitui-nix` builds the isolated Home Manager file tree and verifies
all link targets, the exported Starship config path, and Bash/Zsh hooks. It moves
the checkout and refreshes the anchor before starting the pinned applications.

The runtime renders success/failure lambdas with their palette colors, checks
directory styling and literal AWS formatting using dummy fixtures, checks Git
branch/detached behavior, and exercises a live prompt edit. A private terminal
runs gitui against a throwaway repository, checking actual RON loading, theme
colors, `j`/`k` navigation, F1 help, and live theme edits. Test-only color settings
allow the harness to inspect the theme independently of the calling terminal.

Development tools and terminal-test libraries come from Pixi. Test logic remains
in the justfile, with only the Nix fixture under `src/tests/`. Test configs,
repositories, caches, and logs stay in temporary directories. No Home Manager
activation, real-repository mutation, or deployment is performed.

Validated on 2026-10-19: `check` passed, including all 39 Nix source parses and
the portable deployment tests. The combined Home Manager/runtime check passed
with Starship 1.24.1 and gitui 0.27.0; its temporary report is at
`/tmp/nixfiles-starship-gitui-nix.fBMygw/`.

All 16 host baseline checks passed; the full report is at
`/tmp/nixfiles-baseline.va4Itp/summary.md`. System package lists are unchanged.
Both home profiles retain the same package versions and counts; directly
installing gitui changes its position in the package list. The input pins and
stateVersion values remain unchanged. The Nix lockfile SHA-256 remains
`a9eb0728ead343cc10dee5a55a0ce538f40220fe4115ac641adc42f1bb9fd8dc`.
