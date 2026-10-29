# Explicit repository workflows (NIX-18)

The justfile separates validation, builds, activation, portable dotfiles, and
updates. Pixi supplies the tools and forwards recipe arguments. Deployment is
still deferred; none of these changes activates Jupiter, Mars, or Moon. The
baseline now evaluates all three host configurations, including Moon's planned
installation layout.

## Check and build a host

Run from anywhere inside this checkout:

```sh
pixi run --locked hosts
pixi run --locked check-host jupiter
pixi run --locked plan jupiter
pixi run --locked build jupiter
```

`hosts` discovers names from `nixosConfigurations`; there is no second host list
in the new recipes. `check-host` evaluates the system derivation and reports the
configured hostname, state version, and warnings. `plan` requests a dry run.
`build` realizes the selected system and prints its logical store path, without
creating a `result` link or activating it. Evaluation may fetch pinned sources
or build evaluation dependencies; a successful plan does not prove a full build.
All four recipes refuse changes to the lockfile.

To compare a newly built host against an existing generation in the same store:

```sh
pixi run --locked diff jupiter /nix/store/previous-system-path
```

Replace the example with an actual logical store path. On the matching NixOS
machine, obtain the current generation using `readlink -f /run/current-system`.
The recipe builds the selected candidate, then invokes Nix's
[closure comparison](https://nix.dev/manual/nix/2.35/command-ref/new-cli/nix3-store-diff-closures.html).
It does not switch the system. Build outputs are not given permanent garbage
collection roots by these recipes.

The flake is resolved relative to the justfile's checkout. Moving the checkout
or using paths with spaces requires no committed path change.

## Select a store

`NIXFILES_STORE=auto` is the default. On NixOS, detected by `/etc/NIXOS`, the new
recipes use the system daemon. On other systems they use the writable relocated
store rooted at `NIXFILES_TEST_ROOT`, defaulting to `.pixi/nix-test`:

```sh
NIXFILES_TEST_ROOT=/absolute/writable/scratch pixi run --locked check-host mars
```

The physical store lives below that root; reported paths retain `/nix/store/`
for cache compatibility. `NIXFILES_STORE` can explicitly select `daemon` or an
absolute writable store root. Other values are rejected. Scratch stores use a
private cache under their root and an empty build-users group; daemon calls
retain the daemon's configured build-user policy. Build namespaces must be
available in the container. See the [store notes](baseline.md#testing-from-a-non-nixos-system).
The baseline collector continues to use its scratch store explicitly on every
platform.

## Activation when deployment resumes

`test-host <host>` and `switch <host>` require an explicit configured host, a
matching local hostname, NixOS, and `NIXFILES_STORE=auto` or `daemon`. They invoke
`nixos-rebuild` through sudo with the selected flake host and lock updates
forbidden. `test-host` activates temporarily without setting the boot default;
`switch` also changes the boot default. Home Manager is integrated into the
system activation, so there is no standalone Home Manager switch recipe.

These entry points are prepared for later target-machine work. Their activation
branches have not been exercised on NixOS. Before using them, follow the
[build, live-link setup, target checks, and recovery procedure](baseline.md#validation-and-recovery).
Moon has been installed; its actual generated hardware module still needs to
be synchronized to the repository.

## Initial installation helpers

On the target device's NixOS live USB, select `host` and `user` and enter the
pinned `just`/`jq` shell described in the
[installation guide](../install.md), then run:

```sh
just disko "$host"
just generate-hardware "$host"
just check-host "$host"
```

`disko <host>` **erases, formats, and mounts the configured target disks**. It
prints their paths, builds the host's pinned `system.build.diskoScript` with one
job and two cores, asks `Do you want to proceed? [y/N]`, and executes it through
sudo only after an explicit `y` or `yes`. Empty input, other answers, and EOF
cancel. It is not a preview command. Installation helpers require NixOS and the system store; run them outside
any distrobox.

`generate-hardware <host> [root]` defaults to `/mnt`, which must be mounted. It
scans the current machine without filesystem definitions, parses the generated
module, and registers it with Git's intent-to-add. It refuses an existing
hardware module. Moon conditionally imports its generated file, allowing an
initial build before the scan and automatic inclusion afterward. Review and
commit the generated module before future rebuilds.

After `nixos-install` creates the account, use
`just install-checkout "$host" "$user" [root] [destination]` to preserve the
working tree, Git history, and uncommitted hardware module in the new home. It
uses the evaluated home/anchor and installed UID/GID, excludes Git-ignored build
data, and refuses to overwrite a checkout or a non-symlink anchor. The default
root is `/mnt`; the default checkout is `<home>/Projects/nixfiles`.

The installer clone stays on its normal branch. Record the initial commit and
avoid pulling during installation; detached HEAD is unnecessary.

`just test-install-workflows` exercises these recipes in disposable checkouts
with simulated NixOS detection and stubbed Nix, sudo, mount checks, and hardware
scanning. Checkout copying and link creation run only inside disposable target
roots with the test user's UID/GID. Tests cover confirmation cancellation, Git
history/local edits/cache exclusions, ownership, and refusal to replace existing
paths. They never execute Disko or access real target devices.

## Portable dotfiles

On a home managed by chezmoi, preview and apply separately:

```sh
pixi run --locked dotfiles-diff /absolute/path/to/home
pixi run --locked dotfiles-apply /absolute/path/to/home
```

Both commands require an absolute destination and discover `src/chezmoi` from
the checkout. Each destination has separate config, cache, and persistent state
under ignored `.pixi/chezmoi/`, without using the caller's default chezmoi state.
Preview does not install files. Apply creates live links to the native files in
`src/dotfiles`; moving the checkout requires applying again from its new location.
Application packages are installed separately. Do not use chezmoi for the same
home files owned by Home Manager on NixOS.

## Updates

Update selected direct inputs explicitly:

```sh
pixi run --locked update-inputs nixpkgs home-manager
```

No argument is an error. Unknown input names are rejected before any update,
including when mixed with valid names. Nix's
[named-input update](https://nix.dev/manual/nix/2.35/command-ref/new-cli/nix3-flake-update.html)
refreshes the selected inputs and their dependency graph, while `follows` links
continue to share pins. The recipe displays the lockfile diff; it does not build,
apply dotfiles, or activate anything. Review the changes and run `check` and
`baseline` before building. This workflow change itself refreshes no pins.

`update-flatpak` is an independent, optional command that requires Flatpak on
the calling system. The legacy `nix`, hostless `switch`, `flatpak`, and combined
`update-all` recipes are replaced by these explicit operations.

## Verification

`pixi run --locked check` includes `test-workflows`: stub Nix commands verify
host selection, argument boundaries, lock-preserving evaluation/build flags,
store selection, selected-input updates, and refusal to activate here. Real
chezmoi previews and applies run only in temporary homes, including after
checkout relocation. No real update or activation is run by these tests.

`pixi run --locked test-workflows-nix` uses the existing nixpkgs pin to build two
tiny fixture generations from a temporary checkout with spaces. It exercises
host discovery, evaluation, planning, building, and closure comparison, verifying
that the fixture lockfile stays unchanged and no result link is created. It
does not build a NixOS system.

Validated on 2026-10-19: the portable `check` suite passes, including recipe
formatting/ShellCheck, all 45 Nix parses, the existing application checks, and
the new workflow tests. The fixture build/diff report is
`/tmp/nixfiles-workflows-nix.dhGjX2/`; the final portable workflow report is
`/tmp/nixfiles-workflows.8HTwSJ/`. Pixi argument forwarding was also checked with
a destination containing spaces. The real `check-host jupiter` and `plan mars`
entry points succeed.

All 19 baseline checks pass in `/tmp/nixfiles-baseline.xuWH8X/summary.md`. Both
hosts have empty warning lists. Metadata, package lists, home-file definitions,
and policy match the preceding package-split baseline; the comparison is
`/tmp/nixfiles-workflow-comparison.json`. The lockfile SHA-256 remains
`0feb9b270b85054351b6a1ca0818054fcef6ed251a3e89624d9bb44470d7ee69`.
Full host builds, real input updates, real-home deployment, and NixOS activation
were not performed.

The subsequent [controlled input refresh](input-refresh.md) exercises these
workflows with newer pins and records its compatibility changes and validation.
