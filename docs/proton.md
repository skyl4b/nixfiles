# Proton tools for Skylab

The shared Skylab declaration imports `src/modules/home/proton.nix` on Jupiter,
Mars, and Moon. It installs the unofficial `proton-drive-linux` client and the
official `proton-pass-cli` in Skylab's Home Manager profile. Other users do not
inherit these packages or the Drive service.

## Package updates and the first build

Drive is pinned to upstream release **v3.6.0**, commit
`27201914ee17ce7e0cd51e5cc8f7b788fd62e196`. Its own locked nixpkgs is retained so
the upstream release cache can provide the package without a large local Rust
build. Shared NixOS settings add the project's published Cachix endpoint and
signing key. This trusts that project's CI builds in addition to the existing
caches; the setting takes effect after the first successful system switch.

On an existing installation, prefetch the pinned Drive build once before
`just switch` so that the first rebuild can also use that cache. From the checkout:

```sh
git pull
sudo nix build --no-link --no-update-lock-file --inputs-from . \
  --accept-flake-config \
  proton-drive-linux#default
just switch
```

`--accept-flake-config` accepts the pinned Drive flake's published cache and
signing key for this initial build. Later rebuilds use the configured cache
normally. A cache miss can still require
a source build. To upgrade Drive, change its release tag in `flake.nix` and run
`just update-inputs proton-drive-linux`. Existing repository inputs remain pinned.
Proton Pass CLI currently comes from the repository's main nixpkgs pin at
**2.4.2**, and updates with that input. Use Nix updates for both applications.

## Mount Proton Drive

All three hosts already provide GNOME Keyring and the privileged `fusermount3`
wrapper. The user unit puts `/run/wrappers/bin` first on PATH so FUSE can mount
without running the daemon as root. It inherits the upstream watchdog, memory
limits, session ordering, and clean-unmount behavior.

From Skylab's unlocked graphical session, sign in interactively and start the
mount for this session:

```sh
pdfs login
systemctl --user daemon-reload
systemctl --user start proton-drive.service
pdfs status
```

Alternatively, open **Proton Drive for Linux** (`pdfs-app`) and sign in. The app
can start the service itself. The default on-demand mount is `~/ProtonDrive`.
Opening, modifying, or deleting files there operates on the remote Drive through
the upload queue; keep another copy of trial data while testing.

The repository enables the mount for Skylab's graphical session on all three
hosts. After rebuilding, it starts at the next graphical login; the explicit
`start` command above also starts it in the current session. Before sign-in,
the daemon waits for a saved session rather than mounting the account.

To stop the mount for the current session:

```sh
systemctl --user stop proton-drive.service
```

The next graphical login starts it again. To turn automatic startup off
declaratively, remove the `graphical-session.target.wants` entry from the Home
Manager module; rebuild and stop the service. Home Manager manages the enablement
link and refreshes it when the unit changes.

The packaged tray's automatic startup remains suppressed independently.
Run `pdfs-tray` manually for the tray icon; GNOME hosts already include
AppIndicator. To make its tray autostart declaratively, remove the `Hidden=true`
override from the Home Manager module. Folder selection, sync rules, credentials,
and the GUI configuration remain local and writable.

Use `journalctl --user -b -u proton-drive.service` and `pdfs diagnose` for
diagnostics. After changing the unit, reload the user manager and restart it.
Test a small folder, offline edits, reconnection, conflicts, and suspend/resume
before broadening sync. Settings include a default 5 GiB content-cache budget;
available-offline files are additional, so review storage use on Moon.

This is an unaudited community client. Its content cache, thumbnails, queued
changes, and some metadata are stored unencrypted locally. Moon has no disk
encryption, so Proton's cloud encryption does not protect those local copies
from someone with physical access to the disk. See the upstream
[security model](https://github.com/narrrl/proton-drive-linux/blob/v3.6.0/docs/SECURITY_MODEL.md),
[installation guide](https://github.com/narrrl/proton-drive-linux/blob/v3.6.0/docs/INSTALL.md),
and [configuration](https://github.com/narrrl/proton-drive-linux/blob/v3.6.0/docs/CONFIGURATION.md).

## Use Proton Pass CLI

Sign in and check access from Skylab's own terminal:

```sh
pass-cli login
pass-cli vault list
```

The repository leaves Proton's default keyring storage enabled. Session files
remain local under `~/.local/share/proton-pass-cli/`; no credentials or tokens
are supplied through Nix, the justfile, or Git. The default Linux kernel keyring
is cleared on reboot. Proton documents an optional persistent desktop-keyring
backend using `PROTON_PASS_LINUX_KEYRING=dbus`; unlock the desktop keyring before
using it. See the official [configuration documentation](https://protonpass.github.io/pass-cli/get-started/configuration/).

Runtime authentication and cloud sync must be tested on the target machine.
Repository validation does not log into either account or modify cloud files.
