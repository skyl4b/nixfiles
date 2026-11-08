# Moon: Surface Go 3 deployment notes

`moon` is a Microsoft Surface Go 3 tablet. Confirmed deployment choices:

| Item | Choice |
| --- | --- |
| Desktop | GNOME |
| Memory | 8 GB |
| CPU | Intel Core i3-10100Y, 2 cores / 4 threads |
| Storage | KIOXIA KBG40ZPZ128G NVMe, 119.2 GiB reported by Linux |
| Current OS | NixOS; successful installation reported 2026-10-29 |
| Previous OS | Aurora 44.20260922.1, Fedora/Kinoite based |
| Boot | UEFI; Secure Boot disabled, platform in Setup Mode |
| Connectivity | Wi-Fi only |
| Installation | Replace the current OS; no dual boot |
| Disk encryption | None |
| Applications | Mostly the full current set; review device-specific costs |

The user supplied a read-only inventory from the previous Aurora installation.
It identifies the CPU, storage, drivers, and firmware state above. On 2026-10-29,
the user reported a successful NixOS installation with camera, pen, rotation,
and folio keyboard working. The hardware module generated on Moon is now
included and imported directly. It supplies the detected boot/storage drivers
and Intel microcode default; Disko owns the filesystem declarations.

Use the [installation walkthrough](../install.md) for the live-USB procedure,
key provisioning, hardware scan, and persistent checkout setup.

## Initial configuration

`src/hosts/moon/default.nix` imports the shared system and GNOME modules. The
flake supplies generic Intel CPU and laptop support and reuses the `skylab`
user declared in its `let` block, including the complete home package profile.
The host enables redistributable firmware, early i915 loading, Intel VA-API
media support, and IIO sensors. Thermald adds adaptive Intel thermal management,
and libcamera supplies the `cam` diagnostic tool. It retains the upstream kernel
and GNOME power management defaults; it does not import the first-generation
Surface Go module. Camera operation has been reported working; thermal management still needs
its separate operational check. No camera workaround was required for the
reported working setup.

### Tablet touch interface

Moon adds [TouchUp](https://extensions.gnome.org/extension/8102/touchup/) alongside
the shared GNOME extensions. The pinned package is 1.7.1 and declares GNOME 50
support. It adds a navigation bar, touch gestures for notifications and menus,
and on-screen keyboard improvements, including manually opening the keyboard.
Upstream explicitly supports Dash to Dock integration.

Use the extension's defaults initially and adjust its individual features in
Extension Settings. Some navigation features activate only in touch mode;
compare behavior with the Type Cover attached and detached. Screen Rotate
continues to provide the existing independent rotation control.

After `just switch`, log out and back in. The unlocked system defaults include
TouchUp; if a customized enabled-extension list takes precedence, enable
**TouchUp** in Extensions or run:

```sh
gnome-extensions enable touchup@mityax
```

Test navigation, the keyboard, portrait/landscape transitions, and interaction
with O-Tiling and Dash to Dock on Moon. Package compatibility and configuration
evaluation do not establish runtime behavior on the actual touchscreen.

### Disable touchpad while typing

Moon's Type Cover (`045e:09b5`) reported `Disable-w-typing: n/a` even with GNOME's
`disable-while-typing` setting enabled. In the pinned libinput 1.31.3, an external
USB touchpad only exposes this feature when it has the
[`AttrTPKComboLayout=below` layout hint](https://wayland.freedesktop.org/libinput/doc/latest/device-quirks.html).
Moon's touchpad module supplies that hint through
`/etc/libinput/local-overrides.quirks`, matching only this cover's USB ID and
touchpad device type. Libinput then pairs it with keyboards sharing its vendor
and product IDs. GNOME's existing preference controls whether it is enabled.

After switching, log out and back in so GNOME reloads libinput's quirks, or reboot.
Check the **Microsoft Surface Keyboard Touchpad** entry with:

```sh
gsettings get org.gnome.desktop.peripherals.touchpad disable-while-typing
sudo nix shell --inputs-from . nixpkgs#libinput --command libinput list-devices
```

`Disable-w-typing` should report `enabled` instead of `n/a`; verify that typing
normal letters suppresses new touchpad motion and taps. Physical button clicks
remain available. The user confirmed on 2026-11-08 that this quirk fixed typing
suppression on Moon. If suppression works with
Input Remapper stopped but fails with it running, capture the additional virtual
keyboard entries before extending the quirk; this rule only covers the physical
cover.

### Type Cover touchpad recovery

Moon includes a workaround for the reported Type Cover touchpad problems in
`src/hosts/moon/touchpad.nix`. Both `hid-multitouch` and parent USB-interface
rebinds completed successfully but proved unreliable after suspend. On
2026-10-31, Moon's journal showed `usb_submit_urb(ctrl) failed: -1` and
`usbhid 1-7:1.3: suspend error -5`; the touchpad remained enumerated but produced
no raw events in `evtest`. Running `usbreset 045e:09b5` restored it. The service
uses that full USB device reset for manual recovery.

Moon's later inventory reported kernel `6.18.56`, device quirks `0x0`,
`power/control=on`, and no configured `usbcore.quirks` parameter. Runtime USB
autosuspend was therefore already disabled for the cover at the time checked.
The configuration includes `usbcore.quirks=045e:09b5:g`, enabling
`USB_QUIRK_DELAY_INIT` for this cover. The
[Surface Go 3 initialization report](https://github.com/linux-surface/linux-surface/issues/1059)
and [linux-surface patch](https://github.com/linux-surface/linux-surface/blob/master/patches/6.18/0010-surface-typecover.patch)
describe a touchpad-mode initialization problem addressed by this delay. They
do not establish that it fixes Moon's suspend failure. Moon subsequently confirmed
the parameter was active (`quirks=0x40`, `power/control=on`), but the touchpad
failed on the first wake after reboot with the same control-transfer and suspend
errors. The reset service had no invocations. The delay therefore does **not**
resolve the reported resume failure. It remains for the documented initialization
issue.

Moon offers only `[s2idle]`; its ACPI inventory reports S0/S4/S5, without S3.
Forcing `mem_sleep_default=deep` is not an available alternative on this device.
Runtime autosuspend being disabled does not prevent system suspend.

#### Kernel selection and follow-up

After testing the optional 7.2.10 kernel entry, the user reported **three sleep/wake
cycles without a touchpad failure**, compared with a first-wake failure on 6.18.56.
This supports improved reliability; it does not yet establish a permanent fix or
identify the particular kernel change responsible.

Moon selects `pkgs.linuxPackages_latest`, currently upstream **7.3**, for its
normal boot entry, without a separate kernel specialisation. The initialization
quirk and manual recovery remain available. No linux-surface profile or additional
power-management workaround is enabled.

On Moon, pull the branch and run:

```sh
git pull --ff-only
just switch
sudo reboot
```

Boot the newest generation's ordinary entry to use 7.3. The boot menu retains
the existing two-generation limit. Confirm the selected kernel after login:

```sh
uname -r
cat /sys/module/usbcore/parameters/quirks
cat /sys/bus/usb/devices/1-7/quirks
cat /sys/power/mem_sleep
```

Expect a 7.3 kernel, `045e:09b5:g`, `0x40`, and `[s2idle]` for this pin. Check camera,
pen, touch, keyboard, and rotation, then repeat several suspend/wake cycles using
the same cover position and wake method as the failing 6.18.56 test. Test both a
short sleep and a longer sleep. Do not run manual recovery until a failure has
been observed and its journal captured:

```sh
sudo journalctl -k -b --since "30 minutes ago" --no-pager \
  --grep='PM:|1-7|09[Bb]5|hid-multitouch|usbhid|xhci'
journalctl -b -u surface-touchpad-reset.service --no-pager
```

Record whether the keyboard still works when the touchpad fails. Recover with
`sudo my-reset-touchpad` as needed. If a kernel regression requires reverting,
change Moon's `boot.kernelPackages` to the desired kernel package set, rebuild,
and reboot. A runtime switch cannot replace the running kernel.

All three hosts evaluate without warnings. Repository evaluation is separate from the
user's three successful sleep/wake cycles on 7.2.10. The nixpkgs refresh for Readest
advances Moon to 7.3; repeated wake cycles, longer sleeps, and suspend battery drain
need checking on that kernel.

Automatic boot and wake-up resets are disabled so they cannot hide the result.
The port `1-7` is the one observed on Moon; use the cover's current path if it changes.
There should be no reset-service invocations before manual recovery is requested.
To remove the initialization delay, remove the `usbcore.quirks`
entry from Moon's `boot.kernelParams`, rebuild, and reboot. Kernel quirk parameters
toggle built-in flags, so recheck the device flags when changing kernels.

The script discovers USB devices matching `045e:09b5`, reads their current bus
and device numbers, and invokes `usbreset` for each matching cover. No port or
bus/device number is hardcoded, and discovery does not depend on the HID driver
remaining bound. It waits three seconds, then allows another four seconds for
device discovery. The whole cover resets, so both its keyboard and touchpad
pause briefly. The service runs only on manual requests,
preventing overlapping resets. The pinned
usbutils 019 can return zero even when a reset fails, so the script checks its
success message as well as the exit status.

After pulling and applying the configuration with `just switch moon`, Moon's
PATH includes a command for manually starting the same service:

```sh
sudo my-reset-touchpad
journalctl -b -u surface-touchpad-reset.service
```

A successful oneshot normally returns to `inactive (dead)`, ready for another
request. The journal records the USB bus/device address and reset result, or a
skipped reset if no matching cover is found. If it skips while the cover is
attached, check `lsusb` using `sudo nix shell --inputs-from . nixpkgs#usbutils
--command lsusb` from the checkout. An `ok` result means the kernel accepted the
USB reset; physical touchpad operation still needs checking.
The operation uses the upstream
[usbreset implementation](https://github.com/gregkh/usbutils/blob/v019/usbreset.c)
to issue `USBDEVFS_RESET`; it does not power-cycle the port.

### Rotation with the cover attached

Moon installs and enables [Screen Rotate](https://github.com/shyzus/gnome-shell-extension-screen-autorotate)
(version 29, supporting GNOME 50), allowing automatic rotation independently of
GNOME's tablet-mode detection. Rotation is unlocked by default, and the Auto
Rotate toggle remains available for temporarily locking it. These are unlocked
defaults; personal settings take precedence. Other hosts retain their existing
extension set.

After `just switch`, log out and back in to load the new system extension. If
your existing personal extension list overrides the system default, enable it
once in your GNOME session:

```sh
gnome-extensions enable screen-rotate@shyzus.github.io
gsettings set org.gnome.settings-daemon.peripherals.touchscreen orientation-lock false
```

This changes GNOME's rotation policy; it still needs live accelerometer readings.
If rotation stops after wake-up, run `monitor-sensor` and physically rotate Moon.
Stop it with Ctrl+C, then test `sudo systemctl restart iio-sensor-proxy.service`
and repeat. Readings that change while the screen stays fixed point toward the
desktop; missing readings that recover after restarting the service point toward
the sensor service or its driver. Preserve the journal before restarting it.

### Storage layout

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
decrypted by agenix. For the credential setup used during installation, see
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
ChatGPT is installed system-wide on all hosts. Moon additionally includes KOReader
for ebooks, Rnote, Xournal++, and ZapZap for WhatsApp; see the
[application setup](../maintenance.md#desktop-applications).
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

The initial pinned nixpkgs default kernel was **6.18.56**, above those documented
version floors. Following repeatable Type Cover failures, the user reported three
successful wake cycles on **7.2.10**. Moon follows the latest upstream kernel,
currently **7.3** after the Readest pin refresh. Continue checking touch/pen, cameras,
rotation, sound, connectivity, battery reporting, and repeated suspend/resume.
Check idle/suspend battery drain on the actual device as well.

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

## Follow-up after installation

- Complete any checks not covered by the user's working-camera/pen/rotation/folio
  report, especially suspend/resume battery drain, thermal management, and
  Docker/Podman/Waydroid coexistence.
- Confirm any additional workload requirements. General-purpose virtual machines
  are not currently selected; LTE is out of scope and hibernation is not configured.

For reinstalling, use the [device installation guide](../install.md) and recheck
Moon's disk identifier against the actual device before confirming Disko. Existing
installation success is not a reason to run partitioning recipes on the live
system during ordinary updates.

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

These historical repository checks did not build a complete system or establish
device compatibility. The later user-reported installation and hardware results
are recorded at the top of this page; they are separate from these test logs.

After the virtualization split, repository checks and all 26 baseline checks
pass again (`/tmp/nixfiles-baseline.huSWaD/summary.md`). Focused comparison
confirms Moon's requested Docker, Podman, and Waydroid selection without libvirt,
unchanged home packages, and unchanged Jupiter/Mars system derivations. See the
[virtualization verification](../modernization/virtualisation.md#repository-verification).

After importing Disko and adopting shared zram, all 56 Nix files parse and all
26 baseline checks pass again (`/tmp/nixfiles-baseline.hpcdFn/summary.md`).
Generated storage scripts build and pass static checks without execution.
See the [storage verification](../modernization/moon-storage.md#verification).
