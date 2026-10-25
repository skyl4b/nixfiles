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

Use that exact SHA on Moon so later branch updates do not change the revision
being installed. Bring the matching `nixfiles-secrets` private key separately
on external storage; it must remain available after the internal drive is erased.

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

Clone the installation branch, then select the recorded commit. Replace
`PASTE_RECORDED_COMMIT_SHA` with the full SHA from the development checkout:

```sh
git clone --branch codex/modernization-baseline \
  https://github.com/skyl4b/nixfiles.git /tmp/nixfiles
cd /tmp/nixfiles || exit
git checkout --detach PASTE_RECORDED_COMMIT_SHA
git rev-parse HEAD
git status --short
```

If the repository is private, authenticate GitHub access before cloning. The
shared secrets key is for agenix decryption, not GitHub authentication. Keep
the selected commit and lockfile unchanged throughout the install, apart from
adding Moon's generated hardware module below.

Confirm UEFI mode and inspect the disk:

```sh
test -d /sys/firmware/efi
lsblk -e7 -o NAME,PATH,SIZE,TYPE,MODEL,FSTYPE,MOUNTPOINTS
ls -l /dev/disk/by-id/nvme-eui.01000000000000008ce38e0403d48bea
```

Confirm that this identifier still resolves to Moon's internal 119.2 GiB
KIOXIA KBG40ZPZ128G, not the installer or backup storage. If it does not match,
stop and reconcile `src/hosts/moon/disk-config.nix` with the actual device.

## 3. Build and execute the pinned Disko script

Build the script from this repo's locked inputs. Building it does not modify disks:

```sh
disko_script=$(nix --extra-experimental-features 'nix-command flakes' build \
  --no-update-lock-file --no-link --print-out-paths --max-jobs 1 --cores 2 \
  .#nixosConfigurations.moon.config.system.build.diskoScript)
```

**The next command erases the configured internal drive.** It creates the 1 GiB
EFI partition and ext4 root, then mounts them at `/mnt/boot` and `/mnt`:

```sh
sudo "$disko_script"
findmnt /mnt
findmnt /mnt/boot
```

The script comes from the pinned Disko module already imported by Moon. No
separate `latest` Disko input is fetched. This follows the repository's selected
[Disko layout](moon.md#initial-configuration) and
[upstream filesystem ownership guidance](https://github.com/nix-community/disko/blob/725ea35e410ad83be4931d1bff7e090eacaf3563/docs/quickstart.md).

## 4. Capture and import Moon's hardware configuration

Generate only the hardware module, leaving filesystem definitions to Disko:

```sh
sudo nixos-generate-config --root /mnt --no-filesystems --show-hardware-config \
  > src/hosts/moon/hardware-configuration.nix
```

Review that file. In `src/hosts/moon/default.nix`, add this line inside its
existing `imports` list, keeping its other imports:

```nix
./hardware-configuration.nix
```

Register the new file so the Git-based flake includes it, then evaluate Moon:

```sh
git add --intent-to-add -- src/hosts/moon/hardware-configuration.nix
nix --extra-experimental-features 'nix-command flakes' eval \
  --no-update-lock-file --raw \
  .#nixosConfigurations.moon.config.system.build.toplevel.drvPath
```

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
nix --extra-experimental-features 'nix-command flakes' shell \
  --no-update-lock-file .#nixosConfigurations.moon.pkgs.just \
  -c just provision-identity /run/key-usb/nixfiles-secrets /mnt
```

This puts the root-owned key at `/mnt/var/lib/agenix/identity`. The temporary
Nix shell supplies the installer command without installing the full Pixi
development environment in the live session.

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
Do not repeat the destructive Disko step to retry an installation.

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

Copy the generated hardware module and the updated import back to your main
development checkout, then commit and push them on the installation branch so
the next rebuild retains the device settings. The installer checkout is detached
at the selected commit; its local hardware edits are preserved by the copy above.

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
