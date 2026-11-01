# Doom Emacs

Personal configuration lives in `src/dotfiles/doom/`: `init.el` selects modules,
`packages.el` declares extra packages, and `config.el` contains the settings and
bindings. These files were imported unchanged from the existing personal config.
Org notes remain under `~/Documents/notes/`, as configured; they are not imported.

Nix supplies `emacs-pgtk` in both user profiles, plus the existing editor helpers.
Doom retains its normal writable checkout and package management. No Doom flake
input or second Emacs package manager is added. This follows the
[upstream installation and maintenance workflow](https://github.com/doomemacs/core#install).

## Deploy the personal files

On NixOS, the shared `skylab` declaration imports `src/modules/home/doom.nix`.
Home Manager links the three files individually into `~/.config/doom`, through
the existing checkout anchor. Other users can opt in by adding that module to
their `mkUser.homeModules`. It is not imposed on every new account.

From the checkout on the NixOS machine:

```sh
just switch
just doom-install
just doom doctor
```

The checkout anchor must already point to this repository, as described in the
[installation guide](install.md). An arbitrary checkout location is supported.
If existing Doom files differ, review and merge those changes before applying;
the Home Manager module does not force replacements or change the Doom checkout.

On a machine using the portable deployment instead of Home Manager, install
Emacs and Doom's system dependencies with that machine's package manager, then:

```sh
just dotfiles-diff "$HOME"
just dotfiles-apply "$HOME"
just doom-install
just doom doctor
```

Use one deployment owner for the files. These commands are run as the regular
user. There is no activation hook that downloads Doom or its packages.

## Doom checkout and state

`just doom-install` requires the three deployed personal files. It clones
`https://github.com/doomemacs/core` into the normal Emacs config location only
when that location is absent, then runs `doom install --no-config`. Repeating
it reuses the existing Doom checkout without pulling a new revision. Existing
non-Doom directories are left untouched.

The recipes honor `EMACSDIR` and `DOOMDIR`. Otherwise, they select
`~/.emacs.d` when present, or `${XDG_CONFIG_HOME:-$HOME/.config}/emacs` for a new
installation. Personal files use the XDG `doom` directory, falling back to
`~/.doom.d` when the XDG directory is absent. Legacy `~/.emacs` init files take
precedence over normal directory discovery, so review those before installing.
If using a custom `EMACSDIR` outside Emacs' standard locations, launch Emacs with
the corresponding `--init-directory` argument.

The Doom checkout, downloaded packages, compilation products, caches, and session
state stay outside this repository. Individual file links leave room for local
Doom files such as `custom.el` without adding them to Git.

## Daily maintenance

Edit the files under `src/dotfiles/doom/`; live links make the changes immediately
available. For changes to module selection or package declarations, run:

```sh
just doom sync
```

Then restart Emacs. Normal settings in `config.el` generally only need a reload
or restart. After changing the Nix-provided Emacs version, run `just doom sync`
again. Use `just doom sync --env` when you want Doom to refresh its saved shell
environment, and `just doom upgrade` to update Doom and its packages separately
from Nix. Any Doom command is available through `just doom …`.

The personal config enables Ghostel and automatic tree-sitter grammars. Their
system/native-build dependencies are still handled by the normal Doom workflow;
`just doom doctor` is the next check on the actual machine. This integration
does not reintroduce global project compilers or change the personal settings.

`just test-doom` checks deployment links, checkout relocation, bootstrap/dispatch,
and protection of existing configurations in a temporary home with a simulated
Doom executable. It does not install packages into the real home or claim a full
Doom session has been tested. `just test-doom-nix` additionally builds the Home
Manager file links and checks the personal Lisp with the pinned Emacs reader;
it does not evaluate that Lisp or install Doom's packages.

Validation on 2026-11-01 passed the portable checks, built Home Manager links,
and Lisp reader checks with Emacs 31.1. All three hosts evaluate without warnings,
with unchanged package lists and state versions. All 29 portable links match the
Home Manager ownership map. Logs are `/tmp/nixfiles-doom-check.log`,
`/tmp/nixfiles-doom-nix.log`, and `/tmp/nixfiles-doom-hosts.json`.
