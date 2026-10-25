# Modernization plan

Source: the NixOS project in Vikunja (project 21, task identifiers NIX-1 through
NIX-21), read on 2026-10-18. The intended architecture is idiomatic NixOS and Home
Manager modules, native portable dotfiles, live Home Manager links on NixOS, and
chezmoi deployment on other systems. Each deployed file has one owner and one
canonical source.

Repository implementation stays under `src/`, documentation under `docs/`, and
automation primarily in the root `justfile`. Pixi manages this repository's
development dependencies. The current machine is not running NixOS; evaluation
and build testing here prepare for a future NixOS installation.

## Decisions recorded on 2026-10-19

- Neovim and Emacs are the editors to retain. Helix configuration, its flake
  input, and its binary cache have been removed; NIX-5's Helix migration is
  superseded by that decision.
- The first intended deployment is a new machine named `moon`. Its hardware,
  system choices, and initial stateVersion will be supplied when deployment is
  in scope. Do not create its host configuration or copy Mars/Jupiter hardware
  as a placeholder. Existing hosts remain evaluation references.
- Actual deployment is deferred. Prepare and validate the repository using
  isolated test directories and the relocated Nix store.
- The checkout can live anywhere. A configurable user-local symlink will provide
  a stable anchor for live dotfiles; no fixed checkout path is required.
- Keep the native-file modules simple, without custom assertion guards. Validate
  their links, shell integration, and application behavior through tests.
- Keep editor language servers, linters, and formatters global. Compilers,
  language runtimes, notebook environments, and framework build tools belong to
  projects. Neovim's private provider runtimes are editor dependencies.

On 2026-10-20, the user identified Moon as a Surface Go 3. The
[hardware assessment](../hosts/moon.md) records the proposed upstream-kernel
trial and confirmed GNOME, 8 GB RAM, about 120 GB storage, Wi-Fi-only hardware,
and a replacement installation without encryption. The user prefers mostly the
full application set, with device-specific changes open for proposal. Hardware
inventory and verification of the installation layout remain pending. At the
user's subsequent request, Moon now has its own configuration using generic
Intel/laptop support, GNOME, and planned ext4/EFI filesystems addressed by labels.
No hardware file is copied from the reference hosts. Deployment preparation has
resumed; the earlier deferral still applies to installation and activation.

The [user/profile refactor](user-profiles.md) adds `mkUser`, moves Skylab's
identity out of shared system configuration, and splits home packages into
minimal and complete profiles. The flake's `let` block constructs Skylab's user
once; Jupiter, Mars, and Moon reuse that declaration with the complete profile.

The [GNOME audit and cleanup](gnome-audit.md) replaces Pop Shell with O-Tiling
for dynamic automatic tiling on Jupiter and Moon, declares extension activation,
removes stale/redundant GNOME packages, and fixes the shared GTK4 dark preference.

[Optional virtualization modules](virtualisation.md) now separate Docker,
Podman, libvirt/virt-manager, and Waydroid from shared workstation settings.
Jupiter and Mars retain their service choices; Moon selects Docker, Podman, and
Waydroid without libvirt. Container and Android runtime testing remains a
deployment gate.

[Deployment preparation](../hosts/moon-testing.md) now enables Moon's zram and
conservative Nix build limits, adds optional runtime password-hash file support
to `mkUser`, and replaces age-only cleanup with weekly nh cleanup retaining one
week and at least two generations. Moon displays at most two boot generations.
The supplied Aurora inventory now identifies Moon's CPU, stable NVMe identifier,
existing partitions, UEFI mode, and disabled Secure Boot. The subsequent
[storage preparation](moon-storage.md) adds the pinned Disko input and replaces
manual filesystem definitions with its GPT/EFI/ext4 layout. Zram is now an
overridable shared workstation default; Moon keeps its hardware-specific build
limits. The shared secrets and personal recovery public keys are recorded.
The supplied encrypted password is wired into Moon through agenix. Private-key
provisioning, actual formatting/installation, complete builds, and device tests
remain deployment steps.

Shared defaults now enable OpenSSH and open TCP port 22 on every host. Skylab's
shared account authorizes the personal public key; SSH password authentication,
keyboard-interactive authentication, and direct root login are disabled by
default. The shared agenix identity is not an SSH login recipient.

Moon also enables adaptive Intel thermal management through thermald and installs
libcamera's diagnostic tools. Thermal behavior and camera capture remain device
checks; the upstream kernel and GNOME power manager are retained.

The [Git pilot](git-pilot.md) now supplies native files, an explicitly imported
Home Manager module, the reusable live-link helper, and the chezmoi adapter.
Isolated tests exercise both deployment mechanisms. The helper and pointer setup
are implemented; applying them to an actual user's home remains deferred.

[tmux and WezTerm](terminals.md) also use native files and explicit Home Manager
modules now. tmux plugin packages are exposed through stable XDG paths, with
theme options updated for the pinned plugin. Portable and pinned runtime checks
cover these applications in temporary homes.

The [Home Manager module conversion](home-modules.md) completes NIX-9's program
import work: application/integration modules are listed explicitly under
`src/modules/home/`, and `src/dotfiles/` contains only native files. The subsequent
native-file migrations below extract their custom configuration. The host and
overlay refactor also removes the custom import helper's last consumer.

[Yazi and direnv](yazi-direnv.md) now have native configuration and chezmoi
adapters too. Their Home Manager modules retain packages and shell integration,
with nix-direnv's loader owned separately. Yazi's legacy settings/plugin API was
corrected for the pinned runtime.

[Starship and gitui](starship-gitui.md) now use native TOML/RON files and shared
adapters. Starship retains Home Manager shell integration; gitui is installed
directly to avoid generated-file overlap. Prompt and interactive keybinding/theme
tests cover the pinned applications.

[Bat, bottom, ripgrep, and tealdeer](cli-tools.md) now share native config and
theme files too. Home Manager retains bat's cache rebuild, ripgrep's config
environment variable, and tealdeer's weekly update timer.

[Zellij, Hyfetch, and Zathura](desktop-tools.md) now use native KDL, JSON, and rc
files. This finishes the custom configuration extraction from the program
modules. Eza's shell integration, GitHub CLI, and Home Manager's own enablement
remain in Nix. The home composition's inline commitlint file has also moved to
a shared native file with its own file-link module.

The [host and overlay refactor](host-layout.md) implements NIX-10 through NIX-12.
Both reference hosts use `mkHost`, shared NixOS modules, standard module
arguments, and one overlaid NixOS/Home Manager package graph. Recursive overlay
and cache discovery and `src/utils.nix` are removed. Hardware is isolated per
host, with unchanged source files; target-machine verification for NIX-13 remains
deferred. [API cleanup](api-cleanup.md) now migrates the remaining deprecated
options and helpers, including NVIDIA CDI and Qt integration.
[System policy](system-policy.md) now enables the firewall, records the service
exceptions, and audits remote access, virtualization privileges, and cache trust.
[Input/cache cleanup](inputs-and-caches.md) removes the unused Catppuccin flake,
consolidates nixpkgs inputs, and limits COSMIC cache trust to that desktop.
The user-requested [Rust follow-up](rust.md) also removes `rust-overlay` and the
global Rust toolchain entirely, leaving Rust tooling to individual projects.
[The package split](packages.md) now extracts the home package list, retains
global editor helpers, removes project toolchains, and corrects Neovim provider
wiring. [Host-explicit workflows](workflows.md) and the
[controlled input refresh](input-refresh.md) are validated. A complete
[portable rehearsal](portable-validation.md) also verifies chezmoi's full tree
and application behavior in an isolated Ubuntu home.

## Initial sequence (historical)

1. **NIX-1: establish the baseline.** The migration branch, repeatable collector,
   [observed results and blockers](baseline.md), and recovery instructions are
   recorded. Store-backed checks use a writable relocated store on this machine;
   resolve the recorded source/evaluation blockers before structural changes.
2. **NIX-2: agree and adopt the structure below.** This document defines the
   destination and ownership; the existing `src/` tree remains active until files
   are moved in reviewable changes with working imports.
3. **NIX-3 and NIX-4: prove shared dotfile deployment.** Test a chezmoi source
   adapter against a temporary home, then add a Home Manager module using a
   configurable user-local anchor and `config.lib.file.mkOutOfStoreSymlink`.
   Verify the final link resolves through the anchor into the checkout. Do this
   before bulk moves.
4. **NIX-6: migrate Git as the first small pilot.** Native Git config and ignore
   files provide a contained way to test shared sources and ownership. Preserve
   identity/settings and allow a machine-local identity override. Validate with
   `git config --list --show-origin` in an isolated home first.
5. **NIX-7, NIX-8, NIX-9: migrate the remaining programs incrementally.**
   tmux's Nix-installed plugin paths are now separated from native settings.
   The remaining fragments have become full modules through an explicit import
   list. Their native extraction and the final overlay-consumer conversion are
   implemented; `src/utils.nix` is now removed.

NIX-6 is the first application pilot because its configuration is contained.
During these initial steps, retained inputs kept their existing pins; Helix and
its private dependency were pruned without updating other inputs. The later
[input refresh](input-refresh.md) records subsequent retained-input updates. If baseline
evaluation reveals an option or package error, fix it in a separate small change
before relying on an evaluation comparison.

## Destination structure and ownership (NIX-2)

The main layout is now in place. `src/pkgs/` is reserved for future custom
derivations and is not created as an empty placeholder:

```text
flake.nix
flake.lock
pixi.toml             # Development dependencies and task entry points
pixi.lock
justfile              # Recipes and their embedded scripts
src/
  lib/
    mk-host.nix       # Shared host constructor
    mk-user.nix       # NixOS account and integrated Home Manager constructor
  hosts/
    jupiter/{default.nix,hardware-configuration.nix}
    mars/{default.nix,hardware-configuration.nix}
    moon/default.nix  # Initial configuration; verify its planned storage layout
  modules/
    nixos/            # Shared services, desktops, system policy
    home/             # Home Manager modules and live-link helper
  home/
    default.nix       # Shared home settings and application modules
    profiles/         # Minimal, complete, and shared editor-helper packages
  dotfiles/           # Canonical native application files
  chezmoi/            # Symlink adapters for the native files
  overlays/           # Explicit overlay list
  pkgs/               # Reserved for future custom derivations
  tests/              # Nix fixtures and host-policy snapshot helper
docs/modernization/
```

Keep only entry-point files, README/license, and version-control metadata at the
root alongside `src/` and `docs/`. Runtime environments and test state stay in
ignored `.pixi/` or an explicitly selected scratch directory. Use just recipes
for shell automation instead of adding a root `scripts/` directory. Do not add
a Nix devShell to supply this repository's development tools; add them to Pixi.

| Original source | Destination | Owner |
| --- | --- | --- |
| `src/systems/{jupiter,mars}.nix` | `src/hosts/<host>/default.nix` plus shared `src/modules/nixos/` | NixOS |
| `src/systems/hardware/{addw3,asus_a15}.nix` | Respective `src/hosts/<host>/hardware-configuration.nix` | NixOS; verify on the matching machine |
| `src/systems/desktops/` and `src/systems/cachix/` | `src/modules/nixos/` | NixOS |
| `src/homes/skylab.nix` | Inline `mkUser` calls, `src/home/default.nix`, and `src/home/profiles/` | NixOS account plus integrated Home Manager |
| `src/dotfiles/*.nix` and application `.nix` fragments | Full modules under `src/modules/home/` | Home Manager |
| Native application files and extracted settings | `src/dotfiles/<app>/` | One source; deployment owner depends on the machine |
| `src/overlays/` | `src/overlays/` | NixOS package graph, shared with integrated Home Manager |
| `src/packages/` | `src/pkgs/` | Custom package definitions |

The only old custom package, an unused Copilot derivation with a missing source
input, was removed together with its overlay instead of being moved.

NixOS owns boot, hardware, system services, networking, system packages, and the
integration of Home Manager. Home Manager owns user packages, shell integration,
and all deployed user configuration on NixOS. On other operating systems, chezmoi
owns the portable user files. Do not run both deployment mechanisms for the same
destination in the same home directory.

Native files belong in `src/dotfiles/`, without copied settings in Nix or a second
chezmoi tree. The adapter now lives at `src/chezmoi/`; commands supply that source
directory explicitly, so no root `.chezmoiroot` is needed. Its `symlink_*.tmpl`
files resolve the canonical files relative to `.chezmoi.sourceDir`. The adapter
must not introduce embedded Nix store paths into portable configuration.

For each application, disable its Home Manager-generated config before adding a
live link to the same destination. Keep Nix-only package/plugin integration in
the module.

## Checkout location and live links

Use a configurable anchor such as `${config.xdg.dataHome}/nixfiles` in the Home
Manager module. The deployment workflow will create that user-local symlink
pointing at `justfile_directory()`, discovered when the command runs. This
records the actual checkout path locally instead of committing a machine path
to the repository. The anchor's location is derived from the configured home/XDG
directories and can be overridden.

Pass strings through `config.lib.file.mkOutOfStoreSymlink`, for example:

```nix
config.lib.file.mkOutOfStoreSymlink
  "${config.xdg.dataHome}/nixfiles/src/dotfiles/git/config"
```

The Git pilot supplies that native file. Avoid Nix path literals or
reading the external checkout during evaluation; that would either refer to the
store copy or make evaluation depend on local filesystem contents. Check the
anchor and source files during deployment instead. Home Manager documents the
helper in its [live file-link guidance](https://nix-community.github.io/home-manager/usage/dotfiles.html#advanced-file-behavior).

When the checkout moves, refresh the single anchor using the justfile from its
new location. Existing live file links will follow it without rebuilding their
Home Manager generation. A missing anchor or checkout leaves the links dangling.
The setup command must refuse to overwrite a real directory or file at the
anchor path. The explicit `link-checkout` recipe implements that operation; tests
invoke it only under temporary directories. No pointer or application
configuration has been installed into the current home directory. Chezmoi uses
its discovered source path instead; after moving that checkout, reapply it with
the new source path to refresh its file symlinks.

## Later phases from Vikunja

The table records planned scope. Hardware verification and actual deployment
remain pending, as distinguished from the repository checks above.

| Phase | Tasks | Scope |
| --- | --- | --- |
| P2 | NIX-10–NIX-13 | Shared `mkHost`, `specialArgs`/`extraSpecialArgs`, central overlays, common NixOS modules, verified hardware |
| P3 | NIX-14–NIX-16 | Evaluated API migrations, deliberate firewall/service policy, controlled input updates |
| P4 | NIX-17–NIX-19 | Separate user/project tooling, repository dependencies in Pixi, host-explicit recipes, tested chezmoi deployment on another distro |
| P5 | NIX-20–NIX-21 | All three host configurations validate; complete builds, installation, and target-machine tests remain deployment gates |

After each change, rerun the collector and compare the relevant host/package
results. Before deployment, build and test the matching host using the
[validation and recovery procedure](baseline.md#validation-and-recovery).
Keep hardware changes separate from structural moves and retain all stateVersion
values. NixOS generation rollback will not undo edits to live-linked dotfiles.

The baseline, native application files, explicit Home Manager modules, shared
host composition, overlay consolidation, pinned API cleanup, initial
firewall/service review, input/cache cleanup, home/project package split,
[explicit repository workflows](workflows.md), and the
[controlled input refresh](input-refresh.md) are implemented. The
[portable rehearsal](portable-validation.md) passes in a temporary Ubuntu home;
the [maintenance guide](../maintenance.md) describes current operation.
Fresh-machine onboarding, portable deployment into a real user home, complete
host builds, target-machine verification/activation, and Moon onboarding remain
incomplete. These are deployment gates, not reasons to repeat completed source
refactors or package migrations.
