# Nixfiles

Personal NixOS configurations for `jupiter`, `mars`, and
[`moon` (Surface Go 3)](docs/hosts/moon.md), with Home Manager integrated into each
system. The repository is being prepared on Ubuntu for a future NixOS migration.
Moon is the first intended deployment. Disko defines its replacement layout using
the drive identifier observed on the device; installation and hardware tests
remain pending.

Start with the [setup and maintenance guide](docs/maintenance.md).
For Moon's initial deployment, follow the [installation walkthrough](docs/hosts/moon-install.md).

## Development

Pixi supplies development tools; automation lives in the justfile:

```sh
pixi run --locked check
pixi run --locked hosts
pixi run --locked check-host jupiter
pixi run --locked plan jupiter
```

The commands can also be run directly with `just` when their dependencies are
available. Both NixOS user profiles include `just`; keyboard registration uses
`just remap-keyboard "Keyboard Name"` without Pixi. Pixi currently supplies the
development environment while preparing the migration.

`check` lints recipes, parses Nix, and exercises portable files in temporary homes.
`check-host` evaluates the chosen system; `plan` requests its build plan. Neither
activates anything or refreshes the lockfile. Complete builds and closure
comparisons use the separate `build <host>` and `diff <host> <previous-store-path>`
tasks. See [all workflows](docs/modernization/workflows.md).

## Validation

```sh
pixi run --locked baseline
pixi run --locked test-portable-nix
```

The baseline checks all three hosts and records warnings, packages, policy,
and build plans. The portable rehearsal applies the complete chezmoi tree into
one temporary home, checks every native link, relocates the checkout, and runs
pinned applications. Focused `test-*-nix` tasks check individual app integrations.
Reports are written to fresh temporary directories. These are evaluation and
application tests; they do not prove complete NixOS builds or hardware operation.

On non-NixOS systems, tests use a writable store under ignored `.pixi/nix-test`.
To use another root:

```sh
NIXFILES_TEST_ROOT=/absolute/writable/scratch pixi run --locked baseline
```

Nix supplies actual test applications; repository development dependencies stay
in Pixi. See [store details](docs/modernization/baseline.md#testing-from-a-non-nixos-system)
and the [portable validation results](docs/modernization/portable-validation.md).

## Layout and ownership

Host definitions live in `src/hosts/`, shared NixOS/Home Manager modules in
`src/modules/`, and user composition/packages in `src/home/`. Native settings live
in `src/dotfiles/`; `src/chezmoi/` points to them without duplicating settings.
The checkout can live anywhere. NixOS uses a configurable user-local live-link
anchor; chezmoi discovers its source location. Use one deployment owner per home.

Neovim and Emacs are retained. Editor helpers stay global; project compilers,
runtimes, and notebooks belong to projects. The Rust overlay/global toolchain
and Helix are removed.

The [modernization plan](docs/modernization/plan.md) links the migration history
and recorded decisions. The [input refresh](docs/modernization/input-refresh.md)
records current pins, compatibility fixes, and accepted upstream changes.
