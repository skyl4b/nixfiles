# Explicit Home Manager modules

NIX-9's program-import conversion is implemented. Home Manager now composes the
17 application/integration modules listed in `src/modules/home/default.nix`.
`src/homes/skylab.nix` imports that module list together with the Catppuccin Home
Manager module. Adding a program requires an explicit import.

The later [host refactor](host-layout.md) moves the composition to
`src/home/skylab.nix`, adds the eighteenth module for native commitlint links,
and removes the overlay importer's final dependency on `src/utils.nix`.
After the native-file migrations, the [input audit](inputs-and-caches.md) also
removes the now-unused Catppuccin flake and its module imports.
The subsequent [user/profile refactor](user-profiles.md) moves shared home
composition to `src/home/default.nix` and Skylab's identity into inline `mkUser`
calls in the flake.

The 14 remaining program fragments were moved from `src/dotfiles/` into full
modules under `src/modules/home/`: bat, bottom, direnv, eza, GitHub CLI, gitui,
Home Manager CLI, hyfetch, ripgrep, starship, tealdeer, Yazi, Zathura, and Zellij.
They join the existing Git, tmux, and WezTerm modules. Each now sets its own
`programs.<name>` options within the normal module system.

`src/dotfiles/default.nix` and `programs = import ../dotfiles` are removed.
`src/dotfiles/` contains only native configuration and plugin files. The existing
direnvrc and Yazi smart-enter plugin stay there, with their module references
adjusted for the new location. The remaining CLI settings are still generated
from Nix; extracting their portable native files is the remaining NIX-8 work.
This change does not add chezmoi ownership for those applications.
The subsequent [Yazi/direnv migration](yazi-direnv.md) extracts those two
applications' files and adds their chezmoi adapters.

The overlay importer still uses `src/utils.nix`. That helper is retained until
the separate overlay/package audit replaces its last consumer. Host composition
and overlay behavior are otherwise unchanged.

## Option fixes

The modules use the pinned Catppuccin input's supported
`catppuccin.<app>.enable` options for bat, bottom, gitui, starship, and Yazi.
The home composition imports `inputs.catppuccin.homeModules.catppuccin`.
These replace deprecated aliases without changing the resulting themes.
Eza's deprecated Boolean `icons = true` becomes its equivalent `icons = "auto"`.

The comparison also exposed an invalid `home.shellAliases = [ ]` definition.
The option requires an attribute set, so it is now `{ }`. The previous baseline
did not evaluate that option directly. Its new per-host `home-files` check
evaluates aliases, session settings, and all declared home-file sources and text
hashes, in addition to package lists and system build plans.

## Verification

An isolated before/after evaluation of Jupiter compared all 36 XDG file definitions
and 43 home-file definitions, all package names in their original order,
enabled program states, session variables, and session paths. They match after
normalizing the Yazi plugin's store source location. That plugin was previously
copied through the recursively imported dotfiles directory; its module now
references the same canonical directory directly. The plugin's file list and
SHA-256 hashes match. The corrected empty alias definition is the intended value
change.

Run the checks using Pixi:

```sh
pixi run --locked check
NIXFILES_TEST_ROOT=/absolute/path/to/writable/scratch pixi run --locked baseline
```

The baseline now has 16 checks, including the new file/alias evaluation for each
existing host. These are evaluation and build-plan checks; they do not activate
Home Manager or build/deploy a complete NixOS system. Native config extraction
will require application runtime checks as each application migrates.

Validated on 2026-10-19: `check` passed, including ShellCheck, parsing all 37 Nix
files, and the existing portable Git/terminal tests. The expanded baseline
passed all 16 checks; its full temporary report is at
`/tmp/nixfiles-baseline.ETz5aT/summary.md`. Both hosts retain the same system/home
package names and order as the terminal migration baseline.

Jupiter's recorded module warnings fell from 11 to 5 and Mars's from 10 to 4.
The remaining warnings concern Qt, GNOME/GDM, PulseAudio, and NVIDIA container
integration. Existing `system`/`hiPrio` package evaluation warnings also remain
for the package/host refactor. The Nix input pins and all stateVersion values
are unchanged; the lockfile SHA-256 remains
`a9eb0728ead343cc10dee5a55a0ce538f40220fe4115ac641adc42f1bb9fd8dc`.
