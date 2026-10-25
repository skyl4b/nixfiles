# Moon: Surface Go 3 deployment notes

`moon` is a Microsoft Surface Go 3 tablet. Confirmed deployment choices:

| Item | Choice |
| --- | --- |
| Desktop | GNOME |
| Memory | 8 GB |
| CPU | Intel Core i3-10100Y, 2 cores / 4 threads |
| Storage | KIOXIA KBG40ZPZ128G NVMe, 119.2 GiB reported by Linux |
| Current OS | Aurora 44.20260922.1, Fedora/Kinoite based |
| Boot | UEFI; Secure Boot disabled, platform in Setup Mode |
| Connectivity | Wi-Fi only |
| Installation | Replace the current OS; no dual boot |
| Disk encryption | None |
| Applications | Mostly the full current set; review device-specific costs |

The user supplied a read-only inventory from Moon's current Linux installation.
It identifies the CPU, storage, drivers, and firmware state above. Device-generated
NixOS hardware configuration and operational tests remain installation work.
No reference host's hardware file is copied.

Use the [installation walkthrough](moon-install.md) for the live-USB procedure,
key provisioning, hardware scan, and persistent checkout setup.

## Initial configuration

`src/hosts/moon/default.nix` imports the shared system and GNOME modules. The
flake supplies generic Intel CPU and laptop support and reuses the `skylab`
user declared in its `let` block, including the complete home package profile.
The host enables redistributable firmware, early i915 loading, Intel VA-API
media support, and IIO sensors. Thermald adds adaptive Intel thermal management,
and libcamera supplies the `cam` diagnostic tool. It retains the upstream kernel
and GNOME power management defaults; it does not import the first-generation
Surface Go module. Confirm thermal management and camera operation on the device;
no custom thermal configuration or camera workaround is selected in advance.

The replacement layout is defined in `src/hosts/moon/disk-config.nix`, imported
with the pinned Disko module. It targets
`/dev/disk/by-id/nvme-eui.01000000000000008ce38e0403d48bea`, observed as
`/dev/nvme0n1` in the supplied inventory. Disko is the sole owner of the mount
definitions. The layout uses systemd-boot with UEFI, without encryption or a
disk swap partition:

| Mount | Filesystem | Partition size | GPT and filesystem label |
| --- | --- | --- | --- |
| `/` | ext4 | Remaining space | `nixos` |
| `/boot` | FAT EFI system partition | 1 GiB | `efi` |

The new labels and filesystems are installation choices, not the existing
Aurora layout. Aurora currently has a 600 MiB EFI partition, a 2 GiB ext4 `/boot`,
and a 116.7 GiB Btrfs system/home partition. Applying Disko's destructive mode
will replace those partitions. No formatting or partition changes have run.
Recheck the target identity in the installer. Generated NixOS mounts use
`/dev/disk/by-partlabel/nixos` and `efi`; Disko also writes the matching
filesystem labels. Keep filesystem definitions out of any subsequently generated
hardware module. See the [storage preparation report](../modernization/moon-storage.md).

The initial system state version is `26.11`, matching the current pinned
pre-release platform. The shared user keeps Home Manager state version `23.11`.
Existing Jupiter/Mars versions are unchanged. Review Moon's initial versions if
the chosen installation release changes before the first installation.

Shared workstation settings enable zram with the upstream defaults: zstd compression and a logical
swap capacity of 50% of RAM. This does not reserve half of RAM in advance and
does not provide hibernation. Nix is limited to one concurrent build and two
build cores; these settings reduce build pressure but are not a hard memory cap.
The host module comments record that these limits reflect Moon's hardware,
rather than build limits to apply to every workstation. Zram is an overridable
shared default; existing disk swap on Jupiter and Mars is retained. Moon's
current Aurora installation already uses 7.7 GiB of zram. Compression costs CPU
and the compressed pages still occupy RAM; poorly compressible data benefits
less. See the
[kernel zram documentation](https://docs.kernel.org/admin-guide/blockdev/zram.html).

Shared weekly cleanup retains one week of history and at least two available
generations through nh. Moon's systemd-boot menu displays at most two system
generations; a fresh installation needs a second distinct generation before it
has a fallback. See the [build and testing guide](moon-testing.md).

`mkUser` now accepts an optional runtime password-hash file, including one
decrypted by agenix. Actual credential provisioning remains pending; see
[declarative password setup](../modernization/user-profiles.md#declarative-passwords).

Repository-side preparation can now use:

```sh
pixi run --locked check-host moon
pixi run --locked plan moon
```

Evaluation and build plans do not verify that the planned labels exist or that
this device boots and resumes correctly. No installation or activation has run.

## Application and service scope

Keep Neovim, Emacs, and global editor language servers, linters, and formatters.
Project compilers and runtimes remain project dependencies, as already agreed.
The [GNOME audit and cleanup](../modernization/gnome-audit.md) replaces Pop Shell
with O-Tiling and supplies unlocked system defaults enabling O-Tiling,
AppIndicator, Dash to Dock, and Caffeine. User extension choices take precedence
and survive rebuilds. O-Tiling uses its upstream settings and shortcuts, with
automatic tiling on by default. The desktop uses the native dark preference
and GNOME Console as its standard terminal; the shared Ghostty setup is also
available. Actual window
management, shortcuts, and tablet interaction still need target testing.

The default remains the broad application set. The
[minimal and complete user profiles](../modernization/user-profiles.md) now
allow that choice per host; Moon now uses complete through the shared user.
Selecting minimal would change home packages, not system virtualization services.
The following are proposals for Moon, not changes to either reference host or
decisions to remove packages:

| Existing configuration | Proposal for Moon |
| --- | --- |
| Ollama installed as a home package | Keep local inference optional; avoid provisioning model downloads during installation |
| Firefox and Brave installed system-wide | Keep both initially; selecting one later is an optional storage saving |
| Global editor helpers and Quarto without Python/R engines | Retain the agreed workflow; measure the resulting closure before trimming |

Installed packages do not all imply running services. In particular, the home
package list installs Ollama but does not enable an Ollama service. Model files
would consume additional storage beyond the Nix package closure. No model
downloads have been made here.

### Selected virtualization services

Moon explicitly imports Docker, Podman, and Waydroid. Libvirt and virt-manager
are disabled. The [optional service modules](../modernization/virtualisation.md)
keep Jupiter and Mars's existing selections. The shared account retains Docker
access and omits the unused `kvm` and `libvirtd` memberships on Moon.

Podman keeps its own command and socket, with DNS enabled for its default
network. Its module opens UDP 53 on `podman0` only. Waydroid's upstream module
enables LXC, requires Binder support, adds `psi=1`, and trusts the internal
`waydroid0` interface. Its nftables package avoids the pinned networking script's
legacy iptables preference on current kernels; the host firewall backend is
unchanged.

Initialize Android and choose its image during deployment. No Android image has
been downloaded. Test Waydroid graphics, touch, suspend, and networking in the
GNOME Wayland session, including after Docker and Podman restarts.

## Kernel assessment

Proposed starting point: the ordinary upstream NixOS kernel, then validate on
this device. This follows linux-surface's
[recommendation to try the distribution kernel first](https://github.com/linux-surface/linux-surface/blob/master/README.md).
It is a test plan, not a guarantee that every feature will work unchanged.

The current [linux-surface feature matrix](https://github.com/linux-surface/linux-surface/wiki/Supported-Devices-and-Features#feature-matrix)
was checked on 2026-10-20. Its Surface Go 3 column lists keyboard/trackpad,
touchscreen, pen, Wi-Fi, audio, sensors, and suspend support without marking
those features as requiring the patched kernel. Buttons require upstream 5.15+
and battery reporting requires 5.17+. The camera entry now points to libcamera
and the 6.14 kernel series or newer. Hibernation is listed as unsupported.

The repository's pinned nixpkgs default kernel evaluates to **6.18.56**, above
those documented version floors. That makes upstream a reasonable initial
candidate. Test touch/pen, Type Cover, rotation, sound, connectivity, battery
reporting, and repeated suspend/resume before accepting it. Check idle/suspend
battery drain on the actual device as well.

The [camera support page](https://github.com/linux-surface/linux-surface/wiki/Camera-Support)
identifies Go 3 as IPU3, lists front/rear sensor support, and marks the IR sensor
unsupported. Cameras also need the relevant userspace/firmware and application
integration; changing the kernel alone does not establish working video calls.
Camera support should be checked with libcamera first, then the intended apps.

## Hardware-module selection

The pinned nixos-hardware revision is
`60a624466c08787ee8303393b7d4752d1826f14f`. Its
[Surface Go module](https://github.com/NixOS/nixos-hardware/blob/60a624466c08787ee8303393b7d4752d1826f14f/microsoft/surface/surface-go/default.nix)
explicitly says that its current target is Go 1 and that later models may need
changes. It imports Kaby Lake support, first-generation Wi-Fi firmware handling,
and Surface common configuration. The
[common module](https://github.com/NixOS/nixos-hardware/blob/60a624466c08787ee8303393b7d4752d1826f14f/microsoft/surface/common/default.nix)
selects a patched kernel and supplies a sleep-policy default.

Do not blindly import that profile for a Go 3 upstream-kernel trial. Start with
applicable generic Intel support and a hardware configuration generated on Moon.
Review Surface-specific settings individually. In particular, do not copy the
reference hosts' NVIDIA/PRIME/container-GPU configuration, first-generation
ath10k firmware replacement, or forced sleep-mode settings without evidence
that this device needs them. Keep linux-surface available as a later option if
on-device testing demonstrates a specific missing feature or regression.

## Information still needed

- Provisioning of the shared decryption private key on the target; the encrypted
  password hash and both public recipients are recorded and wired into Moon.
- Any additional workload requirements beyond the selected Docker, Podman, and
  Waydroid support; general-purpose virtual machines are not currently selected.
- Device-generated NixOS hardware configuration after the target layout is
  mounted. Replacement and absence of encryption are already decided.
- Required tablet, pen, camera, and suspend behavior. LTE is out of scope for
  this Wi-Fi-only model; hibernation is not part of the initial plan.

Repeat the relevant read-only inventory checks in the installation medium
before applying the prepared disk layout:

```sh
lscpu
lsblk -o NAME,SIZE,TYPE,MODEL,FSTYPE,MOUNTPOINTS
lspci -nnk
```

These commands do not partition or format anything. The inventory identifies
the real target device and CPU; it does not replace the hardware configuration
generated against the final mounted installation filesystems.

Use the supplied inventory to review the generated hardware configuration in
the installer, complete a full build, then perform the agreed target-machine
tests. Disk operations and activation remain separate deployment steps.

## Repository validation

Validation on 2026-10-20 passed:

- Recipe lint, parsing of 50 Nix files, portable component tests, and workflow
  checks (`/tmp/nixfiles-moon-check.log`).
- All 26 baseline checks for Jupiter, Mars, and Moon, plus Hyprland and the
  flake check (`/tmp/nixfiles-baseline.ozD7Wd/summary.md`). All host warning lists
  are empty; system derivations and build plans evaluate successfully.
- Jupiter and Mars retain their exact previous system derivation paths and
  policy observations after moving the shared user into the flake's `let` block.
- Moon's account and complete home package selection match the shared user,
  including 119 home package entries. Its planned filesystem labels, GNOME/GDM,
  Intel initrd module, and compatibility versions match the declared choices.
- Upstream kernel `6.18.56`, firmware/microcode, IIO sensors, GNOME power profiles,
  and Intel media support are enabled; TLP and NVIDIA container integration are
  disabled (`/tmp/nixfiles-moon-hardware-policy.json`).

These checks do not build a complete system or establish device compatibility.
Target storage verification, a full build, installation credentials, boot,
touch/pen, rotation, camera, and suspend tests remain deployment work.

After the virtualization split, repository checks and all 26 baseline checks
pass again (`/tmp/nixfiles-baseline.huSWaD/summary.md`). Focused comparison
confirms Moon's requested Docker, Podman, and Waydroid selection without libvirt,
unchanged home packages, and unchanged Jupiter/Mars system derivations. See the
[virtualization verification](../modernization/virtualisation.md#repository-verification).

After importing Disko and adopting shared zram, all 56 Nix files parse and all
26 baseline checks pass again (`/tmp/nixfiles-baseline.hpcdFn/summary.md`).
Generated storage scripts build and pass static checks without execution.
See the [storage verification](../modernization/moon-storage.md#verification).
