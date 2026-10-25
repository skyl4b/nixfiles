# Portable Git configuration

Git is the first program migrated from a custom Nix fragment to native files and
an explicitly imported Home Manager module. The pilot implements the shared-file
layout (NIX-3), live-link helper (NIX-4), and Git migration (NIX-6). Target-machine
deployment and onboarding remain deferred.

## Sources and ownership

| Source | Purpose |
| --- | --- |
| `src/dotfiles/git/config` | Canonical Git settings |
| `src/dotfiles/git/ignore` | Canonical global ignore patterns |
| `src/modules/home/git.nix` | NixOS/Home Manager package and link ownership |
| `src/modules/home/live-dotfiles.nix` | Reusable live-file options |
| `src/chezmoi/dot_config/git/symlink_*.tmpl` | Non-NixOS deployment adapter |
| `src/tests/git-pilot.nix` | Isolated Home Manager file-tree fixture |

The former `src/dotfiles/git.nix` fragment is removed. The native `git/` directory
has no Nix module. Git is listed explicitly in `src/modules/home/default.nix`,
which `src/homes/skylab.nix` imports. The subsequent
[module conversion](home-modules.md) removed the recursive program importer.

On NixOS, Home Manager owns the two deployed files. The pinned `programs.git`
module always generates `git/config` when enabled, so this module installs Git
and GnuPG directly, leaving `programs.git.enable` disabled. All
Git settings belong in the native config or the machine-local include. GitHub
CLI is still supplied by the existing `programs.gh` configuration.

On non-NixOS systems, chezmoi owns those files. Each adapter template creates a
symlink to its canonical sibling under `src/dotfiles/git/`, using the discovered
`.chezmoi.sourceDir`. No settings are copied into the adapter. The explicit source
directory keeps the adapter under `src/` without adding a root `.chezmoiroot`.
Chezmoi uses the conventional `~/.config/git` destination in this pilot.
Git, `gh`, GnuPG, and Neovim must be supplied by that operating system as needed.

The adapter follows chezmoi's [source-state attributes](https://www.chezmoi.io/reference/source-state-attributes/)
and [template variables](https://www.chezmoi.io/reference/templates/variables/).
Home Manager uses its [out-of-store link helper](https://nix-community.github.io/home-manager/usage/dotfiles.html#advanced-file-behavior).
Use one deployment owner for each destination home.

## Settings and machine-local identity

The native config preserves the previous identity, diff/merge settings, colors,
push behavior, ordered version suffixes, GitHub CLI credential helpers, and
OpenPGP settings. The `gh` and `gpg` commands replace Nix-store-specific binary
paths. The ignore file retains `*.swp`, `.bin`, `.envrc`, and `.direnv`; Git loads
it from its standard XDG location.

The final include, `config.local`, is relative to the deployed config file.
It is optional and remains in the destination home, outside the checkout. To
override identity after deployment, write that file explicitly:

```sh
git config --file "${XDG_CONFIG_HOME:-$HOME/.config}/git/config.local" \
  user.email local@example.invalid
```

Neither deployment mechanism owns or removes `config.local`. Edit shared settings
in `src/dotfiles/git/config`; use the local include for machine-specific settings.

## Checkout pointer and moving the repository

The Home Manager helper exposes:

| Option | Default/meaning |
| --- | --- |
| `dotfiles.anchor` | `${config.xdg.dataHome}/nixfiles`, an absolute local pointer outside the Nix store |
| `dotfiles.configFiles` | XDG targets mapped to paths relative to `src/dotfiles/` |

The Git module maps `git/config` and `git/ignore` through that anchor. For example,
the resulting live target is `${dotfiles.anchor}/src/dotfiles/git/config`.
Source and destination paths in this mapping must be relative and may not contain
`..` components. An anchor override belongs in the host/user module; the actual
checkout path remains outside tracked configuration.

When deployment resumes, the justfile can set the selected anchor explicitly:

```sh
pixi run --locked just link-checkout /absolute/path/to/the/selected/anchor
```

The recipe discovers the checkout using `justfile_directory()`. It accepts an
absolute anchor path and refuses to overwrite a regular file or directory. It
can refresh an existing symlink, including a dangling one. After moving the
checkout, run it from the new checkout to refresh that single pointer; existing
Home Manager live links then resolve without rebuilding their generation.

Chezmoi discovers its canonical source from the source directory supplied at run
time. After moving its checkout, supply the new source/working-tree paths and
reapply the adapter so its two file symlinks are retargeted. This is a separate
workflow from the Home Manager anchor.

No anchor, application config, or chezmoi state was installed into the current
user's home. Moon still has no host configuration.

## Verification

Run tooling and portable tests using Pixi:

```sh
pixi run --locked check
pixi run --locked test-git
```

`check` includes `test-git`; the second command is useful when changing only the
native files or adapter. Tests create a temporary checkout and destination home,
run chezmoi init/diff/apply/verify, inspect Git configuration origins, verify
ignore behavior, preserve a local identity override, and check live edits and
relocation. The temporary checkout paths contain spaces. Anchor tests also verify
that real files, directories, and relative paths are refused.

Build and inspect the actual Home Manager file tree with Nix:

```sh
NIXFILES_TEST_ROOT=/absolute/path/to/writable/scratch pixi run --locked test-git-nix
NIXFILES_TEST_ROOT=/absolute/path/to/writable/scratch pixi run --locked baseline
```

`test-git-nix` uses the pinned Home Manager library to build only the isolated
file tree. It checks the generated symlink chain, absence of generated Git text,
the package selection, checkout relocation, an anchor override, and rejection of
a relative anchor. It never runs a Home Manager activation script. The baseline
evaluates the existing host references
and requests build plans; full system builds and deployment are separate work.

Validated on 2026-10-19: `check` passed with 36 parsed Nix files and the portable
tests; `test-git-nix` built and verified the isolated file tree; all 14 baseline
checks passed. The full temporary baseline report is at
`/tmp/nixfiles-baseline.r5CJGw/summary.md`. Neither host reports the four former
Git-option deprecation warnings. The Nix input pins and host state versions are
unchanged by this pilot.
