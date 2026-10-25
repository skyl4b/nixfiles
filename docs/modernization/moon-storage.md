# Moon inventory and declarative storage

The user supplied a read-only inventory from the existing Aurora installation
on the Surface Go 3. It establishes:

| Item | Observed value |
| --- | --- |
| OS | Aurora 44.20260922.1, Fedora/Kinoite based |
| CPU | Intel Core i3-10100Y, 2 cores and 4 threads |
| RAM | 7.7 GiB usable from the marketed 8 GB |
| Current swap | 7.7 GiB zram, already active |
| GPU | Intel UHD Graphics 615, i915 |
| Camera controllers | IPU3 IMGU and CIO2, with drivers bound |
| Wi-Fi | Intel AX200, iwlwifi |
| Storage | KIOXIA KBG40ZPZ128G NVMe, 119.2 GiB |
| Firmware | Booted in UEFI mode; Secure Boot disabled; Setup Mode |

Controller drivers bound under Aurora do not prove the complete NixOS camera,
touch, pen, suspend, or battery experience. Those still need device testing.

## Prepared layout

`src/hosts/moon/disk-config.nix` targets the observed stable device identifier:

```text
/dev/disk/by-id/nvme-eui.01000000000000008ce38e0403d48bea
```

The user has already selected replacement of the existing OS without encryption.
The new GPT layout has a 1 GiB FAT EFI partition mounted at `/boot` and an ext4
root partition using the remaining space. GPT partition labels and filesystem
labels are `efi` and `nixos`. Disko generates the NixOS mount definitions
using `/dev/disk/by-partlabel/`; the old hand-written `fileSystems` declarations
have been removed from Moon's host module.

Aurora currently uses a 600 MiB EFI partition, a 2 GiB ext4 `/boot`, and a
116.7 GiB Btrfs system/home partition. Running Disko's destructive mode on the
selected device will replace that entire layout. Recheck its identity from the
installer. No disk-format or mount script was executed during this preparation.

## Input and scope

Disko is pinned at `725ea35e410ad83be4931d1bff7e090eacaf3563`, with its nixpkgs
input following the repository's root input. All existing input nodes and
revisions are unchanged. The graph now has five direct inputs and six lock nodes.
Only Moon imports Disko; the reference hosts retain their storage declarations.

Zram is now a shared, overridable workstation default. This is consistent with
[Fedora's default swap-on-zram policy](https://fedoraproject.org/wiki/Changes/SwapOnZRAM)
and the supplied Aurora inventory. The NixOS default remains zstd with 50% of RAM
as logical capacity; the observed Aurora setup uses a larger logical device.
Existing Jupiter/Mars disk swap is retained. Moon's local build limits remain
one job and two cores, with comments recording the hardware reason.

The shared secrets and personal recovery public keys are recorded in
`src/secrets/secrets.nix`. The supplied encrypted password hash is now wired into
Moon through agenix. The shared private key must be provisioned on Moon before
activation. No private key or plaintext password was added to the repository.

## Verification

Repository checks pass, including lint, all 56 Nix parses, portable component
checks, and workflow checks (`/tmp/nixfiles-disko-check.log`). All 26 baseline
checks pass (`/tmp/nixfiles-baseline.hpcdFn/summary.md`), covering all three host
evaluations, build plans, policy snapshots, Hyprland, and flake check.

Focused configuration and comparison reports are
`/tmp/nixfiles-disko-validation.json` and `/tmp/nixfiles-disko-comparison.log`.
They verify the supplied disk identifier, GPT partition sizes/types, both sets
of labels, mount definitions, shared zram, retained disk swap on the reference
hosts, unchanged account/service/home package selections, and empty warnings.
Only the intended zram/storage observations change from the preceding baseline.
The personal public key parses as a valid Ed25519 recovery recipient.

Disko's generated format, mount, and combined scripts were built
(`/tmp/nixfiles-disko-scripts-build.log`), then checked with Bash syntax-only mode
and ShellCheck using the same exclusions as Disko's upstream checker. They were
not executed. A complete Moon system build and device testing remain pending.
The updated lockfile SHA-256 is
`519ed8421e12898796fbfa3b57f3e4faff6f53f606b974c8fc6e690ed0c5cf02`.

The labels were subsequently simplified to `nixos` and `efi` at the user's
request. All 56 sources parse, focused three-host evaluation passes
(`/tmp/nixfiles-disko-labels-validation.json`), and the regenerated scripts pass
Bash syntax and ShellCheck checks without execution. Only Moon's labels and
generated mount paths change; Jupiter and Mars retain identical derivations.
The full baseline above predates this label-only simplification.
