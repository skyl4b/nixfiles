# Editor cleanup and validation (2026-10-19)

This records the editor cleanup before the [Git pilot](git-pilot.md). That guide
contains the subsequent migration and validation results.

The user no longer uses Helix. Neovim and Emacs are sufficient. The first planned
deployment is a new machine named `moon`, with its details to be supplied later;
actual deployment remains deferred. See the [updated plan](plan.md).

## Changes

- Removed the Helix program configuration, Git input, and dedicated Cachix cache.
- Pruned its private Rust overlay dependency from the Nix lockfile. Every retained
  input keeps its original revision; the remaining root Rust overlay is retained.
- Removed the obsolete `home-manager-update` and `update` generated scripts,
  their `HOME_MANAGER_PATH` variable, and the fixed `~/.config/nixfiles` value.
  Those scripts invoked standalone Home Manager despite the integrated setup.
  Repository automation stays in the justfile.
- Updated syntax checking to skip deleted tracked files, which Git still lists
  until their deletion is staged.

The lockfile SHA-256 after pruning is
`a9eb0728ead343cc10dee5a55a0ce538f40220fe4115ac641adc42f1bb9fd8dc`.
The earlier [baseline](baseline.md) preserves the pre-removal results and hash.

## Checkout location

No fixed checkout directory is required. The planned Home Manager live links
use a configurable user-local anchor, such as
`${config.xdg.dataHome}/nixfiles`, whose target is discovered by the justfile when
setup runs. The actual checkout path is stored in that local symlink. This avoids
embedding the machine's checkout location in tracked Nix files.

An isolated filesystem probe under `/tmp` verified that moving a checkout and
refreshing its anchor restores an existing application config link without
recreating that link. This tests the indirection mechanism; it is not a Home
Manager activation test. The Home Manager helper and setup recipe will be added
with the portable dotfile pilot. No pointer was created in the current user home.

## Validation

Development tools came from Pixi. Nix tests used the existing local chroot store
at `/tmp/nixfiles-nix.OIIJ7t`, preserving logical `/nix/store` paths.

```sh
pixi run --locked check
NIXFILES_TEST_ROOT=/tmp/nixfiles-nix.OIIJ7t pixi run --locked baseline
```

The tooling checks pass, including ShellCheck and parsing all 34 remaining Nix
files. Both hosts' toplevel evaluations, metadata, package-name evaluations, and
build plans pass, as does `flake check --no-build`. The final collector completed
all 14 checks successfully and exited 0. Its full temporary report is at
`/tmp/nixfiles-baseline.Bu6u8P/summary.md`.

An initial flake check ran before the explicit host evaluations and reported an
unregistered `dotfiles` store path. Host evaluation materialized that import, and
an offline retry passed. The collector now runs host evaluations before flake
validation to handle this order with the existing recursive importer.

The resulting metadata retains the installation state versions:

| Host | system.stateVersion | home.stateVersion |
| --- | --- | --- |
| jupiter | `23.11` | `23.11` |
| mars | `24.11` | `23.11` |

Warnings remain for the Catppuccin module namespace and per-program theme options,
Git settings names, eza icons, the Qt platform theme, PulseAudio options, and
NVIDIA container integration. Jupiter also reports the GNOME/GDM option renames.
These are the next API cleanup tasks; they no longer prevent evaluation.

Successful evaluation and build plans do not prove that full systems build or
work on hardware. No complete system build, activation, or deployment was done,
and Moon has no configuration yet.
