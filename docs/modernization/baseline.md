# Migration baseline (NIX-1)

This page preserves the original 2026-10-18 snapshot. Helix was subsequently
removed by user decision; see [validation after the cleanup](validation-2026-10-19.md)
and the subsequent [Home Manager module validation](home-modules.md) for later
results. The old Helix fetch failure below is historical. The current collector
also evaluates home files, session settings, and aliases, for 16 checks in total.

Recorded on 2026-10-18 against commit
`dcf4c769c6b4baac198e2741b6fc1b1a02e94ac1` on
`codex/modernization-baseline`. The tracked Nix configuration and lockfile were
unchanged when checked. The local Pixi manifest and lockfile now supply the
development tools and task entry points; `.gitattributes` and `.gitignore` were
left untouched. This is preparation for returning to NixOS, performed on a
non-NixOS machine.

## Configuration inventory

The flake declares only `nixosConfigurations`, with two `x86_64-linux` hosts.
It does not declare standalone `homeConfigurations`, packages, checks, or a devShell.
The following state versions come from source inspection; full host evaluation
is still blocked by the source fetch failure described below:

| Host | System module | Hardware module | Desktop | system.stateVersion | home.stateVersion |
| --- | --- | --- | --- | --- | --- |
| jupiter | `src/systems/jupiter.nix` | `src/systems/hardware/addw3.nix` (System76 Adder WS 3, Intel/NVIDIA) | GNOME | `23.11` | `23.11` |
| mars | `src/systems/mars.nix` | `src/systems/hardware/asus_a15.nix` (ASUS A15, AMD/NVIDIA) | COSMIC | `24.11` | `23.11` |

Both hosts import `src/homes/skylab.nix` through the NixOS Home Manager module,
with `useGlobalPkgs` and `useUserPackages` enabled. Preserve these state versions
throughout the migration; they are installation compatibility settings.

Root inputs are `nixpkgs`, `home-manager`, `nixos-hardware`, `agenix`, `helix-git`,
`catppuccin`, and `rust-overlay`. The root nixpkgs revision is
`89c2b2330e733d6cdb5eae7b899326930c2c0648`; the root input timestamps in the
lockfile are from November 2025. This baseline deliberately retains the pins.

`flake.lock` SHA-256:
`89c8083891b34a338aacd18481fed7ed432b145701323aa5e6b27af4c01d11fc`.

## Testing from a non-NixOS system

Pixi manages Nix 2.35.3, just, Bash, coreutils, Git, and ShellCheck for this
repository. All automation is embedded in the `justfile` and exposed as Pixi
tasks. Use `pixi run --locked check` for formatting, ShellCheck, and store-free
Nix syntax checks; use `pixi run --locked baseline` for the host baseline.

The baseline uses a local chroot store rooted at the absolute checkout path
`.pixi/nix-test` by default. Store files live at
`.pixi/nix-test/nix/store`, the database under `.pixi/nix-test/nix/var/nix`, and
caches under `.pixi/nix-test/cache`. All are covered by the existing `.pixi/`
ignore rule. Reports go to a fresh temporary directory outside the checkout.

To select another writable root, supply an absolute path:

```sh
NIXFILES_TEST_ROOT=/absolute/path/to/scratch pixi run --locked baseline
```

Nix receives `--store "$NIXFILES_TEST_ROOT"` and an empty `build-users-group` for
this user-owned store. Its logical store path remains `/nix/store`, preserving
compatibility with the standard binary cache. Do not set `NIX_STORE_DIR` to the
scratch path: changing the logical path prevents reuse of ordinary substitutes.
No system-wide store, daemon, or NixOS installation is needed for these tests.
Building and executing store programs requires Linux user and mount namespaces;
this environment successfully built Catppuccin evaluation dependencies in the
relocated store. See the [Nix local store manual](https://nix.dev/manual/nix/2.34/store/types/local-store.html).

Evaluation can download pinned sources and build import-from-derivation
dependencies even with `flake check --no-build` or a system build dry run.
This run used approximately 689 MiB in its scratch store. Network access is
needed on the first run and for uncached dependencies. The initial sandbox-only
attempt could not resolve hosts; fetching succeeded with network access.
Keep the same store/cache root between runs to reuse downloads.

## Observed results

Environment: Ubuntu 24.04 container, development tools supplied by Pixi.
The first run against the default system store failed with
`error: creating directory "/nix/store": Read-only file system`. The relocated
store removed that environment blocker. The follow-up run at
2026-10-18T02:33:40Z used:

```sh
NIXFILES_TEST_ROOT=/tmp/nixfiles-nix.OIIJ7t pixi run --locked baseline
```

The collector completed all 14 checks: 7 passed, 7 failed, and the process exited
1. See [the captured command output](baseline-output.txt) for commands, evaluated
package names, warnings, and errors.

| Check | Result |
| --- | --- |
| Nix version | PASS: 2.35.3 |
| Syntax | PASS: all 38 Nix files parsed using the dummy store |
| Flake outputs (`flake show`) | PASS: jupiter and mars |
| Flake validation (`flake check --no-build`) | FAIL: Helix grammar fetch returns HTTP 404 |
| jupiter metadata/warnings and toplevel evaluation | Both fail at the same grammar fetch |
| jupiter system and Home Manager package names | Both pass |
| jupiter build plan | FAIL: same grammar fetch |
| mars metadata/warnings and toplevel evaluation | Both fail at the same grammar fetch |
| mars system and Home Manager package names | Both pass |
| mars build plan | FAIL: same grammar fetch |

The pinned Helix input references `mi2ebi/tree-sitter-bovex` revision
`de7657a9cc3525b9b77c6d268da09dad5b1346b0`; downloading its GitHub archive
returned HTTP 404. This blocks both complete host evaluations and build plans.
Repairing the grammar source or changing the Helix pin belongs in a separate
input/package change (NIX-5/NIX-16). No full system was built or activated, and
neither host has yet been proven deployable.

Package-name evaluation succeeds for both hosts, but does not force every
derivation dependency or prove that packages can be fetched or built. The
metadata checks also force warnings and therefore encounter the Helix fetch
before producing their JSON. Evaluation nevertheless emits these diagnostics:

- Catppuccin's `homeManagerModules.catppuccin` was renamed to
  `homeModules.catppuccin`.
- `system` was renamed to `stdenv.hostPlatform.system`.
- `pkgs.hiPrio` was removed in favor of `lib.hiPrio`.

The collector keeps separate metadata, evaluation, system-package, home-package,
and build-plan logs for each host and continues after failures. All flake commands
use `--no-update-lock-file`. Keep reports for each migration step.

## Findings to validate during migration

These additional source findings remain to be audited beyond the observed
Helix blocker and evaluation diagnostics.

| Finding | Evidence | Follow-up |
| --- | --- | --- |
| Separate package sets | `flake.nix` imports an overlaid `pkgs` and applies the home function manually, while `useGlobalPkgs = true`; no `nixpkgs.overlays` is set in the NixOS module graph | NIX-10, NIX-11: use module arguments and one shared package set |
| Missing Copilot source input | `src/overlays/copilot-lsp.nix` references `inputs.copilot-lsp-src`, absent from both root inputs and lockfile | NIX-11: remove or repair after checking usage; laziness may conceal the error until accessed |
| Standalone Home Manager update | `home-manager-update` runs `nix flake update && home-manager switch`, but the flake exports no standalone home configuration | NIX-18: deploy integrated Home Manager with the selected NixOS host |
| Possible Home Manager type error | `home.shellAliases = [ ];` in `src/homes/skylab.nix` uses a list | NIX-9/NIX-14: confirm the pinned option type during evaluation |
| NVIDIA container options need audit | Both hardware modules set Docker and Podman `enableNvidia` | NIX-14: check the pinned modules before replacing options |
| AMD host has Intel PRIME setting | Mars uses `intelBusId = "PCI:5:0:0"` alongside AMD hardware imports | NIX-13: verify GPU identities and PCI addresses on Mars before changing anything |
| Firewall disabled | Both host modules set `networking.firewall.enable = false` | NIX-15: inventory required services before declaring policy |
| Portable config has a host path | Helix starts its GPT server from `/home/skylab/Apps/helix-gpt/src/app.ts` | NIX-5: make optional or configurable during native TOML migration |
| Rollback retention is short | Both hosts enable weekly garbage collection with `--delete-older-than 3d` | Retain a known-good generation and defer automatic collection during target-machine validation |

## Validation and recovery

These are instructions for the actual target NixOS machine; they have not been
run in this container. Verify its disk UUIDs and GPU PCI IDs against its hardware
module before activation. Keep the current working generation available in the
boot menu and avoid garbage-collecting it during migration.

First rerun the baseline with the existing lockfile. On a Git-backed flake, new
Nix files must be tracked before flake evaluation can see them. Review and stage
only the intended migration files, keeping unrelated local setup separate.

Then build the selected host explicitly. Substitute `mars` for `jupiter` when
working on Mars:

```sh
nixfiles_host=jupiter
nixfiles_previous_system=$(readlink -f /run/current-system)
nixfiles_candidate=$(nix build --no-update-lock-file --no-link --print-out-paths \
  ".#nixosConfigurations.${nixfiles_host}.config.system.build.toplevel")
nix store diff-closures "$nixfiles_previous_system" "$nixfiles_candidate"
```

After reviewing the build and hardware settings, activate temporarily:

```sh
sudo nixos-rebuild test --flake ".#${nixfiles_host}" --no-update-lock-file
```

Check login, networking, audio, graphics, suspend/resume, and the Home Manager
applications. `test` activates the candidate without making it the boot default.
To return to the running system captured above in the same shell:

```sh
sudo "$nixfiles_previous_system/bin/switch-to-configuration" test
```

Once the test succeeds, make the selected host persistent:

```sh
sudo nixos-rebuild switch --flake ".#${nixfiles_host}" --no-update-lock-file
```

If that switch fails operationally, use `sudo nixos-rebuild switch --rollback`,
or select a retained earlier generation in the boot menu if login is unavailable.
Rollback restores the system generation; it does not revert repository edits or
application data. Future live dotfile links also require restoring their source
files because they point at the checkout, outside the immutable generation.
Use a reviewed Git revert or restore of specific migration files to recover source;
keep unrelated local changes intact.

The command behavior is described in the
[Nix flake check manual](https://nix.dev/manual/nix/2.34/command-ref/new-cli/nix3-flake-check.html),
[Nix build manual](https://nix.dev/manual/nix/2.34/command-ref/new-cli/nix3-build.html),
and [NixOS manual](https://nixos.org/manual/nixos/stable/).
