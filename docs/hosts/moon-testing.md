# Building and testing Moon

The repository checks and build plans pass; a complete system build and physical
device testing are separate steps. This guide does not partition disks or
activate Moon's configuration on the current Ubuntu machine.

For the ordered live-USB procedure, use the [Moon installation walkthrough](moon-install.md).

## Build before installation

From the checkout on a Linux machine with Pixi, use a writable store on a disk
with sufficient free space. The default below is ignored by Git and follows the
checkout; it is not a required installation path. The earlier scratch store in
`/tmp` is on tmpfs on the current machine, so prefer disk storage for this build.

```sh
export NIXFILES_TEST_ROOT="$PWD/.pixi/nix-test"
pixi run --locked check
pixi run --locked check-host moon
pixi run --locked plan moon
moon_system=$(pixi run --locked build moon)
pixi run --locked just _nix path-info --closure-size --human-readable "$moon_system"
```

The earlier plan estimated about 5.8 GiB of downloads and 13.7 GiB unpacked for
missing store paths. Those are plan observations, not the final system closure
size. Allow additional space for existing cache entries, build work, updates,
container images, and Android data. Recheck the fresh plan before downloading.

A successful build prints a `/nix/store/...-nixos-system-moon-...` path. Record
that path, the closure-size output, and the source revision and lockfile used.
It verifies package and generated-system builds; it does not verify Surface
hardware. The build recipe does not install or activate the result. Moon's
configured build limits apply after deployment; build-machine concurrency is
controlled by that machine's own Nix settings.

## Check the device before installation

The current Linux installation on Moon is sufficient for the initial inventory.
Record the following there, then check the selected target disk again from the
installation medium before partitioning:

```sh
cat /etc/os-release
lscpu
free -h
lsblk -e7 -o NAME,PATH,SIZE,TYPE,MODEL,FSTYPE,PARTTYPE,MOUNTPOINTS
ls -l /dev/disk/by-id/
lspci -nnk
test -d /sys/firmware/efi && echo UEFI || echo BIOS
```

If `mokutil` is installed, also run `mokutil --sb-state` to report Secure Boot's
current state. These inventory commands do not modify disks or firmware.

Confirm the physical disk and capacity, firmware/Secure Boot settings, Type
Cover or other keyboard access, Wi-Fi, and basic touch/display operation.
Reconcile the planned `nixos` and `efi` filesystems with the final
layout. Review the hardware configuration generated against the mounted target
filesystems and avoid defining the same filesystems in two modules.

The supplied Aurora inventory identifies the KIOXIA NVMe as
`/dev/disk/by-id/nvme-eui.01000000000000008ce38e0403d48bea`. Disko is now pinned
and owns Moon's layout and mount definitions in
`src/hosts/moon/disk-config.nix`: GPT, a 1 GiB FAT EFI partition, and ext4 root
using the remaining space. The partition and filesystem labels are `efi`
and `nixos`; runtime mounts use their GPT partition labels. Applying the
destructive script later will replace Aurora's three existing partitions.
Only configuration/script generation is performed during repository checks.
See the [storage preparation report](../modernization/moon-storage.md) and
[Disko's quickstart](https://github.com/nix-community/disko/blob/master/docs/quickstart.md).

Moon now initializes Skylab's password from the supplied encrypted hash. Before
running `nixos-install`, provision the shared private key into the mounted
target using the [key provisioning recipe](moon-secrets.md#provision-the-shared-decryption-identity).
The key must be present before installation activation, not just before reboot.

## Validate after booting Moon

Keep the installer USB available during initial testing. From Moon itself:

```sh
systemctl --failed
systemctl --user --failed
swapon --show
zramctl
systemctl is-active sshd
systemctl is-active thermald
cam --list
nix config show max-jobs
nix config show cores
sudo bootctl list
systemctl list-timers nh-clean.timer
```

Expected configuration: zram is present, `max-jobs` is 1, `cores` is 2, and
cleanup runs weekly. The initial install has one system generation; the boot
menu can show two after a second distinct generation exists. Check that the
fallback actually boots. Resetting or pruning profiles manually can bypass the
automated retention policy.

Thermald should remain active using its adaptive configuration. Inspect
`journalctl -b -u thermald` and temperatures during normal work and a sustained
build. Check for unsupported-platform messages before deciding whether any
device-specific thermal settings are needed.

Use `cam --list` to check camera discovery, then test front and rear capture in
GNOME Snapshot and the applications you intend to use. Enumeration alone does
not verify image capture or video-call integration.

From another machine with the personal private key available, test
`ssh skylab@<moon-ip>` using Moon's actual IP address. Public-key login should
succeed; SSH password authentication and direct root login are disabled by
default. The shared `nixfiles-secrets` key is not a login key.

Create the live-dotfile anchor as Skylab, from the persistent checkout:

```sh
pixi run --locked just link-checkout "${XDG_DATA_HOME:-$HOME/.local/share}/nixfiles"
```

The checkout must remain available. Test Neovim, Emacs, GNOME Console, Ghostty,
and the live application configurations. Editing a native dotfile changes the
live source; a system-generation rollback does not revert those edits.

Test these device behaviors during normal use:

- Colemak-DH is selected in Skylab's GNOME session. Check the login-screen layout
  separately when entering the password; its system default remains US International.
- [Register the Type Cover and any external keyboard](../input-remapper.md),
  apply the preset in Input Remapper, and test Caps/Esc, AltGr navigation, and
  reconnect autoload. Device names must be obtained on Moon rather than copied
  from Jupiter's keyboard list.
- GNOME Wayland graphics, touch, pen if used, Type Cover/trackpad, screen
  keyboard, scaling, rotation, and O-Tiling. Change an extension setting and
  confirm that it survives a later rebuild.
- Wi-Fi reconnects, Bluetooth, audio input/output, camera applications, battery
  reporting, and repeated suspend/resume. Measure idle and suspend battery drain.
- Run a disposable test container with each engine:

  ```sh
  docker run --rm docker.io/library/hello-world
  podman run --rm docker.io/library/hello-world
  ```

  These download a small test image. Also check container DNS/outbound access
  and any intended port bindings; successfully pulling an image alone does not
  prove networking from inside the container.
- Initialize Waydroid after choosing its Android image, then test rendering,
  touch, audio, and Android networking. Check coexistence after restarting
  Docker, Podman, and Waydroid, and after suspend/resume. Actual Android image
  downloads and application setup remain target-machine work.

For subsequent changes, build and review the candidate, then use
`pixi run --locked test-host moon` on Moon for temporary activation. Once its
operational checks pass, use `pixi run --locked switch moon`. These recipes
require the matching NixOS host and system store. See
[recovery instructions](../modernization/baseline.md#validation-and-recovery).

## Preparation verification

Repository checks and all 26 host baseline checks pass after these changes
(`/tmp/nixfiles-predeployment-check.log` and
`/tmp/nixfiles-baseline.Dftrid/summary.md`). Focused evaluation confirms Moon's
zram/build limits, the shared cleanup service and timer, the boot-menu limit,
optional password-file binding, and empty host warning lists
(`/tmp/nixfiles-predeployment-validation.json`).

The pinned nh 4.4.2 binary was tested on disposable profiles, with garbage
collection and gcroot cleanup disabled. It retained the newest two generations
when all were older than a week, retained additional recent generations, and
kept the sole generation of a first installation
(`/tmp/nixfiles-retention-test.log`). Real profiles and user credentials were
not modified. A complete Moon build has not yet run.
