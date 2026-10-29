# Install a device with nixfiles

Use this guide from a NixOS live USB on the device being installed. It works
locally at the device console or over SSH. Commands use the selected `host` and
`user` throughout; device-specific storage and hardware belong in `src/hosts/`.

**Disko erases the disks declared by the selected host.** Back up the device and
keep any required secrets private key available outside those disks. Connect
power and keep the installer USB available for recovery.

## 1. Prepare the host and installation revision

Before starting, the selected host must exist in `flake.nix`, with the correct
architecture, boot configuration, Disko layout, and administrator account with
working credentials. Inspect `src/hosts/<host>/disk-config.nix` for its actual
disk identifiers. Do not copy another device's identifiers. The existing
Jupiter/Mars reference configurations need their own Disko configuration before
using this partitioning workflow.

Publish the reviewed configuration and lockfile on the installation branch and
record its commit. Run a complete `just build <host>` in a development environment
before erasing the target. Moon has been installed successfully; that does not
validate a different host or later revision.

Download the [NixOS minimal ISO](https://nixos.org/download/) matching the target
architecture. The current hosts use 64-bit Intel/AMD (`x86_64`). Have a physical
keyboard available; use the graphical ISO if you need a live desktop instead.
The installed desktop comes from the selected host configuration, independently
of the ISO. The current configurations use UEFI and unsigned bootloaders, so boot
in UEFI mode with Secure Boot disabled unless you have configured signed boot.

Bring any required secrets private key separately. Keep private keys outside the
repository; encrypted `.age` files and public recipient keys belong in Git.

## 2. Make the local TTY comfortable

The minimal ISO logs in as `nixos` with passwordless sudo. These optional commands
are for the device's local Linux console, not a graphical terminal or SSH client.

List console keyboard layouts, then select the one matching your physical
keyboard. Colemak-DH example for US ANSI (Z angle mod):

```sh
localectl list-keymaps | grep -Ei 'colemak|mod-dh'
sudo loadkeys mod-dh-ansi-us
```

For US ISO keyboards, use `mod-dh-iso-us`; ortholinear/matrix keyboards have
`mod-dh-matrix-us`. Console names differ from XKB desktop names: `colemak_dh`
is not the kbd console map name. For another layout, use the name from
`localectl list-keymaps`. To return to US
QWERTY, run `sudo loadkeys us`. The console keymap affects the device's TTYs; it is
separate from per-user GNOME/COSMIC input sources and Input Remapper presets.

Increase the console font on a high-resolution display:

```sh
sudo setfont ter-v32n
```

`ter-v32n` is a 32-pixel Terminus font supplied by the installer; `ter-v16n` is a
smaller alternative. These changes last for the live session. In an SSH session,
your client machine supplies the keyboard layout and terminal font instead.
The [NixOS manual](https://nixos.org/manual/nixos/stable/#sec-installation-manual)
describes these console controls.

To keep console preferences on the installed system, set them in that host's
NixOS module (with `pkgs` in its arguments), for example:

```nix
console = {
  keyMap = "mod-dh-ansi-us";
  font = "ter-v32n";
  packages = [ pkgs.terminus_font ];
};
```

The shared keymap is an overridable default. Persistent console settings apply
to all TTY users on that host; they do not replace desktop layout preferences.

## 3. Connect to the network, optionally continue over SSH

On the device, configure Wi-Fi:

```sh
sudo nmtui
curl -I https://cache.nixos.org
```

Choose **Activate a connection** in `nmtui`, select the network, enter its
password, and exit. Graphical ISO network controls work too.

To continue from another computer, set a temporary password for the live `nixos`
account and display the device's address and SSH host-key fingerprint:

```sh
passwd
sudo systemctl start sshd
ip -br address
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

From the other computer, substitute the device's actual IP address and connect:

```sh
ssh nixos@DEVICE_IP
```

Compare the displayed host-key fingerprint with the device console. Enter the
temporary live password. You can optionally install your personal public key
from the client for later live-session connections:

```sh
ssh-copy-id -i /path/to/personal-key.pub nixos@DEVICE_IP
```

Your personal private key stays on the client. The temporary password only
belongs to the live environment; installed-user credentials come from NixOS
configuration. The [installer's SSH setup](https://nixos.org/manual/nixos/stable/#sec-installation-booting-networking)
supports either a password or an authorized public key. Keep the device powered
and run the remaining commands in the live system, outside a distrobox.

## 4. Clone and select the host and user

In the live console or SSH session:

```sh
git clone --branch codex/modernization-baseline \
  https://github.com/skyl4b/nixfiles.git /tmp/nixfiles
cd /tmp/nixfiles || exit
git branch --show-current
git rev-parse HEAD
git status --short
```

Compare the commit with the revision you prepared. Stay on the normal branch and
do not pull during installation. A private repository requires GitHub access;
the shared agenix secrets key is not a GitHub login key.

Set these to actual existing host and user names before continuing:

```sh
host=YOUR_HOST_NAME
user=YOUR_USER_NAME
```

For example, Moon uses `host=moon` and `user=skylab`. The account and Home Manager
configuration must be declared for that host. Enter a shell with the pinned
installer tools and keep using it for the remaining steps:

```sh
export host user
nix --extra-experimental-features 'nix-command flakes' shell \
  --no-update-lock-file \
  ".#nixosConfigurations.${host}.pkgs.just" \
  ".#nixosConfigurations.${host}.pkgs.jq"
```

Pixi is not needed in the installer. Exporting the names preserves them when
entering the Nix shell.

## 5. Verify storage, partition, and mount

```sh
test -d /sys/firmware/efi
lsblk -e7 -o NAME,PATH,SIZE,MODEL,FSTYPE,MOUNTPOINTS
ls -l /dev/disk/by-id/
cat "src/hosts/$host/disk-config.nix"
```

Compare the configured disk identifiers with the actual target device. Once
you have confirmed the intended disks:

```sh
just disko "$host"
findmnt /mnt
findmnt /mnt/boot
```

The recipe builds the locked Disko script with one job and two cores, displays
the configured disks, and asks **Do you want to proceed? [y/N]** before running
it through sudo. Only `y` or `yes` proceeds, case-insensitively. Empty input,
`no`, other answers, or closed input cancels without modifying disks. It requires
NixOS and the system store. The selected host's Disko configuration owns its
partition sizes, filesystems, and mountpoints; `/mnt` is the target root in this
guide, and `/mnt/boot` assumes the host mounts its EFI partition at `/boot`.

## 6. Generate and review hardware configuration

```sh
just generate-hardware "$host"
just check-host "$host"
```

The first recipe scans the current device against `/mnt`, omits filesystem
entries so Disko remains their owner, parses the generated Nix, and registers
`src/hosts/<host>/hardware-configuration.nix` with Git's intent-to-add. It refuses
to overwrite an existing hardware module. Review an existing module for the
actual device instead of regenerating it blindly.

Each host must import its hardware module; Moon imports its generated module
automatically when present. New host definitions should follow that convention.
An alternative mounted root can be supplied as the second recipe argument.

## 7. Provision credentials when the host uses agenix

Skip this section only if the selected host has another configured credential
source. For hosts using the repository's shared identity at
`/var/lib/agenix/identity`, choose one way to make its private key available.

With a separate key USB, identify its filesystem UUID and mount it read-only:

```sh
lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINTS
sudo mkdir -p /run/key-usb
sudo mount -o ro /dev/disk/by-uuid/KEY_USB_FILESYSTEM_UUID /run/key-usb
identity=/run/key-usb/nixfiles-secrets
```

Replace the UUID with the key USB's filesystem UUID and adjust the key path.
Alternatively, while installing over SSH, copy the key from the client:

```sh
scp /path/to/nixfiles-secrets nixos@DEVICE_IP:/tmp/nixfiles-secrets
```

Then in the device's live session:

```sh
chmod 0600 /tmp/nixfiles-secrets
identity=/tmp/nixfiles-secrets
```

Provision and check the identity before installation activation:

```sh
just provision-identity "$identity" /mnt
sudo ssh-keygen -y -P '' -f /mnt/var/lib/agenix/identity >/dev/null
```

For a password secret, set its actual filename (the current shared user uses
`skylab-password.age`) and check decryption without displaying the hash:

```sh
secret=skylab-password.age
sudo nix --extra-experimental-features 'nix-command flakes' shell \
  --no-update-lock-file ".#nixosConfigurations.${host}.pkgs.agenix" \
  -c sh -c 'cd src/secrets && exec agenix -d "$1" --identity /mnt/var/lib/agenix/identity >/dev/null' \
  sh "$secret"
```

Both checks must succeed. A password secret must contain a password-hash line,
not the cleartext password. See [credential setup](hosts/moon-secrets.md).

## 8. Install and preserve nixfiles for the new user

The following skips the root-password prompt, so first ensure that the selected
administrator has working credentials and sudo access. If that is not configured,
configure it before proceeding or omit `--no-root-passwd` to set a root password.

```sh
sudo nixos-install --root /mnt --flake ".#$host" \
  --no-update-lock-file --no-channel-copy --no-root-passwd \
  --max-jobs 1 --cores 2
sudo nixos-enter --root /mnt -c "passwd --status $user"
```

For password-enabled accounts, expect status `P`. SSH-only accounts may be
intentionally locked; validate their login and administrative access before
rebooting. If installation fails, keep filesystems mounted and diagnose the
failure. **Do not repeat Disko to retry installation.**

After installation has created the account:

```sh
just install-checkout "$host" "$user"
```

This copies the current working tree and Git metadata to the configured user's
`~/Projects/nixfiles`, including the generated hardware module and uncommitted
source changes. Git-ignored build environments and caches are excluded. It reads
the home and live-dotfile anchor from that user's evaluated configuration, uses
the account's installed UID/GID, and creates the anchor pointing to the checkout
as it will exist after reboot, without `/mnt` in the symlink target.

It owns newly created directories and the copied checkout as the selected user,
leaves existing parent-directory ownership alone, refuses to overwrite a checkout
or a non-symlink anchor, and refuses symlinked destination parents in the mounted
target. It requires a regular source clone, not a linked Git worktree.

To choose another absolute checkout path inside the installed system:

```sh
just install-checkout "$host" "$user" /mnt /absolute/path/to/nixfiles
```

The checkout location is not hardcoded into Nix configuration. For an existing
checkout, use normal Git updates and `just link-checkout` rather than copying
over it. Before future rebuilds, commit and push the generated hardware module
from the copied branch, or copy it back to the development checkout and commit
it there.

## 9. Reboot

```sh
sync
sudo reboot
```

Boot the internal drive and log in as the configured user. Reconnect Wi-Fi;
installer network credentials are not automatically declared in nixfiles. Check
the graphical login-screen layout when typing a password; it can differ from the
user's desktop layout. Keep the installer USB for recovery.

## After the first boot

Test the selected device's graphics, input devices, network, audio, suspend,
rotation, cameras, and any configured containers or Android support. For the
Surface-specific checklist, see [Moon testing](hosts/moon-testing.md).

SSH now uses the installed user and its configured authorized keys. The new
installation has different SSH host keys from the live session; verify the new
fingerprint on the device console before updating the client's known-host entry.

Both current user profiles include `just`. Full repository development checks
still require their development tools; until Pixi is replaced, bootstrap them
from the installed checkout. Set `host` again after reboot before running:

```sh
host=YOUR_HOST_NAME
nix shell ".#nixosConfigurations.${host}.pkgs.pixi" -c pixi shell --locked
just check
```

Daily recipes such as
`just remap-keyboard "Keyboard Name"` work directly from the installed checkout.
