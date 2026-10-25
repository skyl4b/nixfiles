# Host composition and shared NixOS modules

NIX-10 through NIX-12 now use the planned structure: each reference host has its
own directory, common system settings are modules, and Home Manager uses the
same overlaid package set as NixOS. The remaining recursive importer is removed.

```text
flake.nix
src/
  lib/mk-host.nix
  hosts/
    jupiter/{default.nix,hardware-configuration.nix}
    mars/{default.nix,hardware-configuration.nix}
  home/skylab.nix
  modules/
    nixos/
      common.nix
      nix.nix
      caches/cosmic.nix
      desktops/{gnome,cosmic,hyprland}.nix
    home/
  overlays/{default,agenix}.nix
  dotfiles/commitlint/commitlint.config.js
  tests/host-policy.nix
```

The old `src/systems/`, `src/homes/`, and `src/packages/` directories are gone.
There are currently no active custom package derivations; `src/pkgs/` can be
introduced when an actual custom package needs it, without an empty placeholder.

## Composition and package scope

`src/lib/mk-host.nix` constructs a NixOS system for a named host. It supplies
`inputs` and `username` through `specialArgs` and
`home-manager.extraSpecialArgs`, and imports the Home Manager file as a normal
module. The former manual `pkgs` import and function application are removed.
`nixpkgs.hostPlatform` supplies the selected platform.

The helper retains `home-manager.useGlobalPkgs` and `useUserPackages`. Its
`nixpkgs.overlays` setting now applies the explicit agenix/Rust overlay list
within the NixOS module graph, so program modules and the home package list see
the same package set. Agenix still comes from its existing flake input; Rust's
existing pin and configured home toolchain remain unchanged.

The upstream hardware-module lists remain explicit in the flake's two host
declarations. Passing them through the helper preserves their original position
relative to the host modules, including Jupiter's graphics-package precedence.
Machine-specific disk and GPU settings live only in each host's hardware file.

The unused Copilot overlay and derivation referenced a nonexistent
`copilot-lsp-src` input. No configuration consumed them, so both are removed
without adding a new dependency. `src/utils.nix` has no remaining consumer and
is removed. Adding an overlay now requires an explicit list entry.

## Shared and host-specific settings

`common.nix` contains the existing shared account and group memberships, locale,
NetworkManager, portals, keyboard, printing, PipeWire, Bluetooth, Flatpak,
firmware service, virtualization, XWayland, and workstation packages.
`nix.nix` contains the existing Nix settings, cleanup schedule, unfree-package
policy, and explicit cache import. Cache URLs and keys retain their prior values.
The desktop modules moved without content changes.

| Host | Settings kept explicit |
| --- | --- |
| Jupiter | GNOME, System76 hardware-module selection, firmware-manager package, UEFI bootloader, system stateVersion 23.11 |
| Mars | COSMIC, AMD hardware-module selection, resolved DNS, Tailscale, Avahi, controller/Steam support, KDE Connect, Podman DNS, UEFI bootloader, system stateVersion 24.11 |

Home Manager's stateVersion remains 23.11. Existing firewall and NVIDIA container
settings retain their previous behavior for the separate API/policy review.

## Home composition and portable files

The home composition is now `src/home/skylab.nix`. Its remaining inline
commitlint configuration moved to a native file and gained a live-link module
and chezmoi adapter. The file's bytes match the former generated text. There are
now 18 explicit Home Manager module imports, including this file-link module.
Package selections and development-tool placement are otherwise unchanged.

## Hardware scope

The two hardware files moved byte-for-byte from their old locations. Existing
filesystem UUIDs, swap devices, kernel settings, and PRIME bus IDs are preserved.
This completes hardware isolation, not physical validation: Mars's AMD host still
uses its old `intelBusId` field and needs target-machine review. No disk or GPU
values were inferred from the current container. No Moon host or hardware file
has been created; deployment details remain deferred.

## Verification

```sh
pixi run --locked check
NIXFILES_TEST_ROOT=/absolute/path/to/writable/scratch pixi run --locked baseline
```

The collector now has 18 checks. Its two new host-policy snapshots record defined
storage and GPU settings, services, accounts, network/Nix policy, session values,
and exact system/home package paths. The snapshot helper is read with `--impure`
to allow importing the local test file; the existing host derivation evaluations
and flake checks remain pure.

Before/after snapshots were captured separately so this change can be compared
against the original policy. Hardware and desktop file hashes were also checked
directly. These checks do not build complete systems or activate either host.

Validated on 2026-10-19: `check` passed with all 43 Nix sources parsed and the
portable deployment checks, including commitlint's link. All 18 baseline checks
passed; the report is `/tmp/nixfiles-baseline.Krtcmf/summary.md`.

The saved policy snapshots under `/tmp/nixfiles-host-structure-before.LJD7GT/`
match the refactored hosts exactly, including package store paths and ordering,
graphics packages, filesystem/swap settings, accounts, services, and session
values. Both hardware files and all three desktop files are byte-identical.
The only changed Home Manager file entry is commitlint's live link to its
byte-identical native source.

The shared graph exposes two overlays. Agenix's derivation matches the home
package, and both scopes select Rust 1.91.1. Host/Home Manager state versions and
Nix pins are unchanged; the lockfile SHA-256 remains
`a9eb0728ead343cc10dee5a55a0ce538f40220fe4115ac641adc42f1bb9fd8dc`.
Existing Qt, GNOME/GDM, PulseAudio, NVIDIA container, and `hiPrio` warnings remain
for the API audit. The agenix overlay's old `system` attribute warning is gone.

The subsequent [API cleanup](api-cleanup.md) migrates these remaining warnings,
updates the retained Hyprland module, and extends the collector to 19 checks.
Its NVIDIA container option change is the only edit to the hardware files after
the byte-preserving structural move documented above.
