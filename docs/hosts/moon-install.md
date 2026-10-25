# Installing NixOS on Moon

This installs the repository's `moon` configuration from a NixOS live USB.
**The Disko execution step erases Moon's internal KIOXIA drive and replaces
Aurora.** Back up your data and the shared secrets private key off that drive
first. Keep Moon connected to power and keep the installer available for recovery.

The configuration has passed evaluation. A complete Moon build and installation
have not been performed here. Run the
[build-before-installation checks](moon-testing.md#build-before-installation)
on the development machine before erasing Moon.

## 1. Publish the installation revision and bring the private key

Use the `codex/modernization-baseline` branch for the reviewed modernization
changes. Commit all required source files, the lockfiles, documentation, and the
encrypted password secret before installing. Local Pixi environments and test
stores are ignored. Keep the `nixfiles-secrets` private key outside Git.

After committing, push the branch and record its full commit SHA:

```sh
git push --set-upstream origin codex/modernization-baseline
git rev-parse HEAD
```

Compare that SHA with the one printed after cloning on Moon. The clone stays on
the normal branch, and its checkout does not change unless you pull or switch
revisions. Do not pull during installation. Bring the matching `nixfiles-secrets`
private key separately on external storage; it must remain available after the
internal drive is erased.

Download the current [NixOS minimal ISO for 64-bit Intel/AMD](https://nixos.org/download/)
and write it to a bootable USB. It is suitable for this manual installation and
has a smaller live environment. Have the Type Cover or an external keyboard
available: the minimal ISO has no graphical desktop. The installed system will
still use GNOME as declared by this repository. The graphical ISO is also valid
if you need a desktop or touch input during setup; open its terminal and follow
the same steps without using its graphical partitioning wizard.

The ISO's release does not change this repo's pinned nixpkgs or Moon's state
version. See the
[official installation manual](https://nixos.org/manual/nixos/stable/#sec-installation).

## 2. Boot the live USB and connect to Wi-Fi

Boot Moon from the USB in UEFI mode, with Secure Boot disabled as in the supplied
inventory. The minimal ISO logs in at a console as `nixos`, with passwordless
sudo. Connect to Wi-Fi through NetworkManager's text interface:

```sh
sudo nmtui
```

Choose **Activate a connection**, select your Wi-Fi network, and enter its
password. Exit the interface, then check HTTPS connectivity:

```sh
curl -I https://cache.nixos.org
```

On a graphical ISO, its desktop network controls work too. Run all installation
commands in the live system, outside a distrobox. These are manual install
steps; do not also run the graphical installer's partitioning wizard. The live
console initially uses its own keyboard layout, not Skylab's Colemak-DH setting.

Clone the installation branch and record its current revision:

```sh
git clone --branch codex/modernization-baseline \
  https://github.com/skyl4b/nixfiles.git /tmp/nixfiles
cd /tmp/nixfiles || exit
git branch --show-current
git rev-parse HEAD
git status --short
```

If the repository is private, authenticate GitHub access before cloning. The
shared secrets key is for agenix decryption, not GitHub authentication. Keep
the selected commit and lockfile unchanged throughout the install, apart from
adding Moon's generated hardware module below. Staying on the branch makes it
easy to commit that module afterward.

Confirm UEFI mode and inspect the disk:

```sh
test -d /sys/firmware/efi
lsblk -e7 -o NAME,PATH,SIZE,TYPE,MODEL,FSTYPE,MOUNTPOINTS
ls -l /dev/disk/by-id/nvme-eui.01000000000000008ce38e0403d48bea
```

Confirm that this identifier still resolves to Moon's internal 119.2 GiB
KIOXIA KBG40ZPZ128G, not the installer or backup storage. If it does not match,
stop and reconcile `src/hosts/moon/disk-config.nix` with the actual device.

Enter a Nix shell supplying the pinned `just` command and `jq` (used by host
checks). Keep using this shell for the remaining installation steps; Pixi is not
needed in the installer:

```sh
nix --extra-experimental-features 'nix-command flakes' shell \
  --no-update-lock-file \
  .#nixosConfigurations.moon.pkgs.just \
  .#nixosConfigurations.moon.pkgs.jq
```

## 3. Partition and mount with Disko

**The next command erases the configured internal drive.** It prints the disk
paths, builds the Disko script from this repo's locked input, then executes it
through sudo. It creates the 1 GiB EFI partition and ext4 root and mounts them
at `/mnt/boot` and `/mnt`:

```sh
just disko moon
findmnt /mnt
findmnt /mnt/boot
```

The recipe uses one build job and two cores, refuses a scratch store, and must
run on the NixOS live system. No separate `latest` Disko input is fetched. This
follows the repository's selected [Disko layout](moon.md#initial-configuration)
and [upstream filesystem ownership guidance](https://github.com/nix-community/disko/blob/725ea35e410ad83be4931d1bff7e090eacaf3563/docs/quickstart.md).

## 4. Generate Moon's hardware configuration

```sh
just generate-hardware moon
just check-host moon
```

The first command scans the current machine with `/mnt` as the mounted target
root. It writes `src/hosts/moon/hardware-configuration.nix`, omitting filesystem
definitions so Disko remains their owner. It parses the generated Nix and
registers the file with Git's intent-to-add so flake evaluation sees it. Moon
imports the generated file automatically when present. No manual import edit is
needed, and the command refuses to overwrite an existing hardware module.

Review that module before continuing. An alternative mounted root can be passed
as a second argument, for example `just generate-hardware moon /mnt/target`.
Hardware generation must run on Moon, not the development machine.

## 5. Provision and check the private key

On the minimal ISO, external drives are not automatically mounted by a desktop.
If the key is on a separate USB drive, identify that drive's filesystem UUID and
mount it read-only. Substitute its actual UUID below, not Moon's internal drive:

```sh
lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINTS
sudo mkdir -p /run/key-usb
sudo mount -o ro /dev/disk/by-uuid/KEY_USB_FILESYSTEM_UUID /run/key-usb
```

The following command assumes `nixfiles-secrets` is at the root of that USB
filesystem. Adjust the absolute source path if you stored it elsewhere.
Use the existing provisioning recipe with the actual absolute path to your
private key and the mounted target root:

```sh
just provision-identity /run/key-usb/nixfiles-secrets /mnt
```

This puts the root-owned key at `/mnt/var/lib/agenix/identity`. Use the `just`
command supplied by the Nix shell opened earlier.

Check that the key can be used without a passphrase, and that it decrypts the
secret. Neither command displays the private key or password hash:

```sh
sudo ssh-keygen -y -P '' -f /mnt/var/lib/agenix/identity >/dev/null
sudo nix --extra-experimental-features 'nix-command flakes' shell \
  --no-update-lock-file .#nixosConfigurations.moon.pkgs.agenix \
  -c sh -c 'cd src/secrets && exec agenix -d skylab-password.age --identity /mnt/var/lib/agenix/identity >/dev/null'
```

Both must succeed before installation. The secret must contain the single
password-hash line generated earlier, not the cleartext password. See
[credential setup](moon-secrets.md) for details.

## 6. Install Moon

```sh
sudo nixos-install --root /mnt --flake .#moon \
  --no-update-lock-file --no-channel-copy --no-root-passwd \
  --max-jobs 1 --cores 2
```

This builds/downloads into the target store and installs the bootloader. The
explicit job/core limits apply during installation; Moon's own Nix settings
take over after boot. The command skips the root-password prompt because
Skylab's password is initialized from agenix and the account has sudo access.
Direct root SSH login remains disabled.

If installation fails, keep the filesystems mounted and diagnose the error.
Do not repeat `just disko moon` to retry an installation.

Check the initialized account without displaying its hash:

```sh
sudo nixos-enter --root /mnt -c 'passwd --status skylab'
```

The password status should be `P`. A locked (`L`) or passwordless (`NP`) account
needs investigation before rebooting.

## 7. Preserve the checkout and live-dotfile anchor

The temporary checkout disappears at reboot. This example places it under
Skylab's `~/Projects/nixfiles`; that is a choice for this walkthrough, not a
hardcoded configuration requirement. Adjust both paths if choosing another location.

```sh
sudo install -d -m 0755 /mnt/home/skylab/Projects
sudo cp -a "$PWD" /mnt/home/skylab/Projects/nixfiles
sudo install -d -m 0755 /mnt/home/skylab/.local/share
sudo ln -s /home/skylab/Projects/nixfiles /mnt/home/skylab/.local/share/nixfiles
sudo nixos-enter --root /mnt -c \
  'chown -R skylab:users /home/skylab/Projects/nixfiles /home/skylab/.local'
```

The symlink uses the path as it will exist on Moon, without `/mnt`. Its location
matches the current Home Manager anchor default. After relocating the checkout,
use the existing `just link-checkout` recipe to refresh it.

The copied checkout remains on `codex/modernization-baseline`, including the
generated hardware module. Commit and push that module once GitHub authentication
is available, or copy it back to the development checkout and commit it there.
The initial revision was recorded before this device-specific addition.

## 8. Reboot and validate

```sh
sync
sudo reboot
```

Remove the installer when appropriate so Moon boots its internal drive. Log in
as `skylab` using the password whose hash you encrypted. Wi-Fi credentials from
the live session are not declared in this repository; reconnect using GNOME if
needed. Skylab's desktop session defaults to Colemak-DH; the login screen retains
the system's US International default, so check its layout indicator while
entering the password. Follow the [first-boot checks](moon-testing.md#validate-after-booting-moon),
including SSH from another machine, thermald, cameras, suspend, and containers.

The installed user profile includes `just`. Daily recipes such as keyboard
registration can run directly from the checkout:

```sh
cd ~/Projects/nixfiles || exit
just remap-keyboard "Keyboard Name"
```

Use the keyboard's actual Input Remapper device name. Full development checks
still use the existing development dependencies. Until Pixi is replaced, the
pinned Pixi package can supply those tools temporarily:

```sh
nix shell .#nixosConfigurations.moon.pkgs.pixi -c pixi shell --locked
just check
```

Use the `just` recipes inside that development shell. Keep the
installer and backups until login, boot, networking, and recovery are verified.
