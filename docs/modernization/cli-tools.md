# Native bat, bottom, ripgrep, and tealdeer configuration

These four CLI tools now share native files between Home Manager and chezmoi,
continuing NIX-8. Their Nix modules retain packages and integrations. No custom
assertion guards are added.

| Canonical source under `src/dotfiles/` | XDG target |
| --- | --- |
| `bat/config` | `bat/config` |
| `bat/themes/` | `bat/themes/` |
| `bat/LICENSE-catppuccin` | `bat/LICENSE-catppuccin` |
| `bottom/bottom.toml` | `bottom/bottom.toml` |
| `bottom/LICENSE-catppuccin` | `bottom/LICENSE-catppuccin` |
| `ripgrep/ripgreprc` | `ripgrep/ripgreprc` |
| `tealdeer/config.toml` | `tealdeer/config.toml` |

Home Manager links these targets through `dotfiles.anchor`. Refresh the anchor
after moving the checkout. The chezmoi templates link to the same sources;
reapply chezmoi with its new source directory after moving a checkout. No fixed
checkout path is required. Chezmoi uses the conventional `~/.config` destination.

## Packages and integrations

Bat remains enabled through Home Manager, retaining batdiff, batman, batgrep,
batwatch, and the activation step that rebuilds its theme cache after linking
files. Native `bat/config` selects `Catppuccin Mocha`; the theme directory is a
live link. Editing bat's config takes effect on the next invocation. Editing
theme assets requires rebuilding the application's cache:

```sh
bat cache --build
```

On non-NixOS systems, run that command after applying the chezmoi files and after
changing a theme. It writes compiled assets to the user's cache directory; no
compiled cache is checked into this repository. Chezmoi does not install tools
or run cache rebuilds automatically.

Ripgrep retains its package and `RIPGREP_CONFIG_PATH` session variable through
Home Manager. The native file keeps smart-case matching. When using chezmoi,
configure this variable in the destination shell:

```sh
export RIPGREP_CONFIG_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/ripgrep/ripgreprc"
```

Tealdeer keeps its colors, formatting, and automatic refresh interval of 720
hours. Its existing Home Manager weekly `tldr-update` timer is also preserved.
The timer is a Nix-only integration; chezmoi deploys only the native config.

## Settings and theme provenance

Bat's config and ripgrep's arguments are byte-identical to their former generated
files. Parsed tealdeer settings and bottom theme colors match the previous
generated configuration. Bottom retains the 750 ms refresh interval,
case-sensitive regex process searches, Celsius, and cache-memory monitoring.

Bottom 0.11.3 no longer reads `enable_gpu_memory`. The native config uses
`disable_gpu = false`, its supported setting for enabled GPU monitoring. The
pinned source's config flags and GPU selection logic were checked directly.
The runtime test disables GPU collection only for its isolated terminal sessions;
actual GPU reporting needs target-machine validation.

Theme assets come from the existing pinned Catppuccin sources:

| Asset | Upstream revision |
| --- | --- |
| Bat Mocha XML | [catppuccin/bat](https://github.com/catppuccin/bat/tree/6810349b28055dce54076712fc05fc68da4b8ec0), 2025-06-29 |
| Bottom Mocha styles | [catppuccin/bottom](https://github.com/catppuccin/bottom/tree/eadd75acd0ecad4a58ade9a1d6daa3b97ccec07c), 2025-04-18 |

Bat's XML is byte-identical to the pinned theme, and bottom's style tables retain
all parsed values. Both MIT licenses are included and deployed. Native theme
updates are deliberate file changes; updating Nix inputs alone does not replace
these vendored assets.

## Verification

```sh
pixi run --locked check
NIXFILES_TEST_ROOT=/absolute/path/to/writable/scratch pixi run --locked test-cli-tools-nix
NIXFILES_TEST_ROOT=/absolute/path/to/writable/scratch pixi run --locked baseline
```

`check` includes `test-cli-tools`, which verifies chezmoi links, TOML and theme XML
parsing, live editing, and checkout relocation. `test-cli-tools-nix` builds an
isolated Home Manager file tree, checks the cache hook and timer, and runs the
pinned applications after moving the checkout. Checkout and XDG paths contain
spaces.

The runtime builds bat's theme cache and renders highlighted Rust, exercises
ripgrep's smart-case matching and explicit override, renders a local tealdeer
page with automatic updates disabled, and starts bottom in private terminals.
Live edits verify config loading, including bottom's actual theme colors.
All configs, caches, pages, search fixtures, and outputs stay in temporary
directories. No Home Manager activation or deployment is performed.

Development tools and terminal-test libraries come from Pixi. Test automation
lives in the justfile, with the isolated Nix fixture in `src/tests/cli-tools.nix`.

Validated on 2026-10-19: `check` passed, including all 40 Nix source parses and
portable deployment checks. The combined Home Manager/runtime check passed
with bat 0.26.0, bottom 0.11.3, ripgrep 15.1.0, and tealdeer 1.8.1; its temporary
report is at `/tmp/nixfiles-cli-tools-nix.ju1fFS/`.

All 16 host baseline checks passed; the full report is at
`/tmp/nixfiles-baseline.btYWKl/summary.md`. Both hosts retain their package lists
and order, session settings, warning content, and state versions. Only the
expected file entries for these four applications differ. The Nix input pins
are unchanged; the lockfile SHA-256 remains
`a9eb0728ead343cc10dee5a55a0ce538f40220fe4115ac641adc42f1bb9fd8dc`.
