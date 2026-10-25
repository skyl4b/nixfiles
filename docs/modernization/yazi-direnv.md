# Native Yazi and direnv configuration

Yazi and direnv now share native configuration between Home Manager and chezmoi,
continuing NIX-8. Their Home Manager modules retain package and shell integration;
the common live-link helper owns the native files and directories.

## Sources and ownership

| Native source | Purpose |
| --- | --- |
| `src/dotfiles/yazi/yazi.toml` | Natural sorting, directories first, hidden files initially off |
| `src/dotfiles/yazi/keymap.toml` | Smart-enter on `l`, edit on `e`, hidden toggle on `H`, help on `?` |
| `src/dotfiles/yazi/plugins/smart-enter.yazi/main.lua` | Synchronous enter/open plugin |
| `src/dotfiles/yazi/theme.toml` | Select the Mocha flavor in both light and dark terminal modes |
| `src/dotfiles/yazi/flavors/catppuccin-mocha.yazi/` | Pinned colors, syntax theme, and licenses |
| `src/dotfiles/direnv/direnv.toml` | Strict environment evaluation and one-hour warning timeout |
| `src/dotfiles/direnv/direnvrc` | Keep per-project layout state in the XDG cache |

The native Home Manager modules map seven targets through `dotfiles.anchor`.
Three Yazi TOML files, its two native directories, and both direnv files are live
links. They follow a refreshed checkout anchor after relocation. Chezmoi's
`src/chezmoi/dot_config/{yazi,direnv}/` adapters point at the same native sources.
Reapply chezmoi with the new source path after moving its checkout.

Plugin and flavor directories are linked as directories, so their files remain
editable in the checkout. Yazi's generated settings, keymap, theme, plugin/flavor
definitions, init.lua, and Catppuccin integration are left disabled or empty.
Direnv's generated config and stdlib are also left empty; their settings live in
the native files.

Home Manager still enables the applications and their configured shell hooks.
Yazi's `yy` wrapper is retained. Direnv retains
`programs.direnv.nix-direnv.enable`, which separately owns
`direnv/lib/hm-nix-direnv.sh`. That Nix-only loader points into the store;
portable files contain no Nix store paths. Chezmoi does not deploy this loader or
install applications. On another operating system, supply Yazi and direnv and
configure their shell integration there; nix-direnv is optional when using Nix.

## Yazi API corrections

The pinned application is Yazi 25.5.31. The former Nix settings used `[manager]`
and `[[manager.prepend_keymap]]`, while that version reads `[mgr]`. The previous
plugin was also named `init.lua`, while the pinned loader reads `main.lua`.
The native files use the supported layout and synchronous entry annotation,
with `plugin smart-enter` and `ya.emit`. The editor binding uses the supported
blocking shell command without the obsolete `--confirm` flag.

These corrections make the intended sorting and bindings effective. The pinned
[default settings](https://github.com/sxyazi/yazi/blob/v25.5.31/yazi-config/preset/yazi-default.toml),
[plugin loader](https://github.com/sxyazi/yazi/blob/v25.5.31/yazi-plugin/src/loader/loader.rs),
and [shell command implementation](https://github.com/sxyazi/yazi/blob/v25.5.31/yazi-core/src/tab/commands/shell.rs)
were checked against the real runtime.

The theme is packaged as a native Yazi flavor. Its syntax theme is resolved
relative to the flavor directory by Yazi, so it works with custom XDG paths
without a fixed home or checkout path. The former theme's
`~/.config/yazi/Catppuccin-mocha.tmTheme` reference is removed.

## Theme provenance

Assets come from the existing pinned theme packages, without updating Nix inputs:

| Asset | Upstream revision |
| --- | --- |
| Mocha/mauve Yazi colors | [catppuccin/yazi](https://github.com/catppuccin/yazi/tree/043ffae14e7f7fcc136636d5f2c617b5bc2f5e31), 2025-08-06 |
| Mocha syntax theme | [catppuccin/bat](https://github.com/catppuccin/bat/tree/6810349b28055dce54076712fc05fc68da4b8ec0), 2025-06-29 |

The flavor TOML preserves all parsed color settings, removing only the old
syntax-theme path. The XML is byte-identical to the pinned syntax theme. Their
MIT licenses are included as `LICENSE` and `LICENSE-tmtheme` in the deployed
flavor directory. Future theme updates are deliberate native-asset changes;
updating the Nix lockfile alone does not replace these vendored files.

## Direnv behavior

`strict_env = true` and `warn_timeout = "1h"` are unchanged. The native direnvrc
keeps the existing cache layout:

```text
${XDG_CACHE_HOME:-$HOME/.cache}/direnv/layouts/<SHA-1 of the project path>
```

The function memoizes by working directory and uses quoted `printf` calls for
path handling. The normal direnv authorization gate still applies. No projects
are trusted automatically. Direnv documents its config, stdlib, and library
loading in the [manual](https://direnv.net/man/direnv.1.html).

## Verification

```sh
pixi run --locked check
NIXFILES_TEST_ROOT=/absolute/path/to/writable/scratch pixi run --locked test-yazi-direnv-nix
NIXFILES_TEST_ROOT=/absolute/path/to/writable/scratch pixi run --locked baseline
```

`check` includes `test-yazi-direnv`: chezmoi deployment into a temporary home,
file/directory link checks, TOML and Lua parsing, ShellCheck, syntax-theme XML and
license checks, live edits, and checkout relocation. Development/test tooling
comes from Pixi; scripts live in the justfile.

`test-yazi-direnv-nix` builds an isolated Home Manager file tree, checks shell
integration and the nix-direnv library link,
and refreshes the anchor after moving its checkout. It runs pinned Yazi and
direnv in the relocated store. Private terminal tests exercise Yazi's actual
bindings and plugin, including directory entry, file opening through a chooser,
a temporary editor, hidden/help behavior, natural sorting, and live config edits.
Direnv tests authorization, strict failure handling, distinct cache paths,
loading the nix-direnv library, and live stdlib edits.

All application configs, project allow records, caches, and editor outputs are
under temporary test directories. No real home activation, external file opener,
project flake build, graphical rendering check, or deployment is performed.

Validated on 2026-10-19: `check` passed with all 38 Nix sources parsed and the
portable Git, terminal, Yazi, and direnv tests. The combined Home Manager/runtime
test passed using Yazi 25.5.31, direnv 2.37.1, and nix-direnv 3.1.0; its temporary
report is at `/tmp/nixfiles-yazi-direnv-nix.WSVX2V/`. Both the temporary checkout
and XDG config paths contain spaces.

All 16 host baseline checks passed; the full report is at
`/tmp/nixfiles-baseline.ZrXtxV/summary.md`. Both hosts retain their system/home
package names and order. Parsed theme colors, syntax-theme XML bytes, and direnv
settings were compared with the previous generated files and preserved as
described above. The Nix input pins and stateVersion values are unchanged; the
lockfile SHA-256 remains
`a9eb0728ead343cc10dee5a55a0ce538f40220fe4115ac641adc42f1bb9fd8dc`.
