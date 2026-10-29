# Setup and maintenance

This is the current operating guide. The [modernization plan](modernization/plan.md)
and its linked reports record how the repository reached this state.

Jupiter and Mars are reference NixOS configurations with integrated Home Manager.
[Moon, a Surface Go 3](hosts/moon.md), is the first installed device. It uses
GNOME and the complete user profile on an
8 GB RAM, 119.2 GiB NVMe, Wi-Fi-only device. The installation replaced Aurora
without disk encryption. Disko defines a 1 GiB EFI partition and ext4 root on
the drive's observed stable device identifier, using `nixos` and `efi`
labels for the new layout. Recheck the disk from the installer before applying
that layout. The supplied inventory confirms UEFI and Secure Boot disabled.
The user reported a successful installation on 2026-10-29, including working
camera, pen, rotation, and folio keyboard. The generated hardware module still
needs to be committed from Moon. The [device installation guide](install.md)
covers local TTY setup, optional SSH, confirmed Disko execution, and copying the
checkout into the installed user's home.

## Work on the repository

With Pixi available, run from inside the checkout:

```sh
pixi run --locked check
pixi run --locked hosts
pixi run --locked check-host jupiter
pixi run --locked plan jupiter
```

Pixi supplies repository development tools. The manifest and lockfile are the
dependency source; no Nix devShell is needed. Automation lives in the justfile.
Host definitions and user declarations are under `src/hosts/` and `flake.nix`,
shared modules under `src/modules/`, shared home settings/package profiles under
`src/home/`, and native configuration under `src/dotfiles/`. `src/chezmoi/`
contains adapters pointing to those native files.

### Select a user package profile

Each host passes user modules to `mkHost`. `mkUser` defines both the account and
integrated Home Manager configuration directly from its arguments. The flake
defines `skylab = mkUser { ... };` once in its `let` block, then reuses it:

```nix
users = [ skylab ];
```

Choose `minimal` for daily tools, Neovim, Emacs, and all shared editor helpers.
Choose `complete` to add the specialized applications from the previous full
list. All three hosts currently share complete. Profiles select home
packages; desktop and system services are configured separately. See
[profile contents and constructor arguments](modernization/user-profiles.md).

### GNOME desktop defaults

Jupiter and Moon use O-Tiling for automatic window tiling, with AppIndicator,
Dash to Dock, and Caffeine enabled through unlocked system defaults. Users can
change their enabled extensions, and those choices survive rebuilds. The
declarations live in `src/modules/nixos/desktops/gnome.nix`; they apply only to
GNOME hosts.
O-Tiling uses its upstream settings and shortcuts; adjust them in its preferences
if needed. GNOME Console is retained as the standard desktop terminal; Ghostty
is supplied by the home modules with Cascadia Code NF and the shared
[terminal configuration](modernization/terminals.md). See the
[GNOME audit and cleanup](modernization/gnome-audit.md) for
the pinned extension version, package choices, and validation limits.

### Keyboard layout

Skylab's shared user declaration imports `src/modules/home/keyboard.nix`, setting
Colemak-DH (`us`, variant `colemak_dh`) in the user's GNOME input sources and
COSMIC keyboard configuration. The preference belongs to Skylab's Home Manager
configuration, independently of the minimal/complete package profile.

Home Manager reapplies the declared preference during activation. The GNOME
setting is writable, while COSMIC's keyboard file is managed by Home Manager.
System keyboard defaults remain US International for the graphical login screen
and `us-acentos` for the text console. Check the login layout when typing the
password; this change does not configure the installer keyboard either.

For local TTY layout and font changes, including persistent per-host console
settings, see [console setup](install.md#2-make-the-local-tty-comfortable).
These system-wide console settings are separate from the user's desktop layout.

Input Remapper is enabled on every host. Register each keyboard once with
`just remap-keyboard "Keyboard Name"` to copy the shared preset and
enable autoload for that device. The GUI configuration stays writable. See
[keyboard registration and remap behavior](input-remapper.md).

### Memory and local builds

Zram is an overridable shared workstation default (`zramSwap.enable =
lib.mkDefault true`), using the upstream compression/size defaults. Existing
disk swap remains configured on the reference hosts. Moon's one-job/two-core
Nix build limit is host-specific because of its CPU and 8 GB RAM.

### SSH access

All hosts enable OpenSSH by default and open TCP port 22 through the host
firewall. Skylab's shared user declaration authorizes the personal public key
ending in `eduardo@farinati.dev`. Connect as `skylab` using the matching private
key. SSH uses public-key authentication; password and keyboard-interactive
authentication and direct root login are disabled by default. Hosts can
override these shared defaults.

The `nixfiles-secrets` key is used for agenix decryption and is not authorized
for SSH login. These declarations take effect when the host configuration is
installed or activated.

### Virtualization services

Each host imports the features it needs from
`src/modules/nixos/virtualisation/`. Jupiter uses Docker and libvirt/virt-manager;
Mars also uses Podman. Moon uses Docker, Podman, and Waydroid, without libvirt or
virt-manager. These system services are independent of the home package profile.
The shared user gains Docker and libvirt groups only when their services are
enabled. See [service choices and deployment tests](modernization/virtualisation.md).

### Run checks with a writable Nix store

On a non-NixOS machine, Nix tests use an ignored writable store under
`.pixi/nix-test`. Select another absolute root when needed:

```sh
NIXFILES_TEST_ROOT=/absolute/writable/scratch pixi run --locked baseline
NIXFILES_TEST_ROOT=/absolute/writable/scratch pixi run --locked test-portable-nix
```

Both commands write fresh reports under the temporary directory. The baseline
checks all three host configurations and their build plans. The portable rehearsal applies
chezmoi into a temporary home and tests real applications. Neither command
activates a system or installs configuration into your current home. Application
builds need the container's namespace/socket support and may fetch pinned binaries.
See [store details](modernization/baseline.md#testing-from-a-non-nixos-system).

Use the focused `test-*-nix` tasks when changing an application's native files or
Home Manager integration. New Nix files must be tracked for Git-based flakes to
include them. Review and stage only the intended files.

## Portable setup when deployment resumes

Install the intended application binaries separately using the package manager
chosen for that machine. Chezmoi installs configuration and links; the repository's
Pixi environment is not a complete desktop application environment.

Preview the destination before applying:

```sh
pixi run --locked dotfiles-diff /absolute/path/to/home
pixi run --locked dotfiles-apply /absolute/path/to/home
```

The source checkout is discovered automatically. There is no required checkout
location. These commands use destination-specific chezmoi state under ignored
`.pixi/chezmoi/`, rather than the user's default chezmoi state. For a real home,
review existing files and preserve the previous configuration before applying.

The adapters create live links. Editing `src/dotfiles/<app>/` changes what the
application reads immediately; some applications need a reload. Reapplying is
unnecessary for a content edit. After moving the checkout, run preview/apply
from the new location to refresh link destinations. Removing the checkout leaves
those links dangling.

Portable deployment intentionally omits Nix-only integration:

- Install and enable shell hooks for the chosen shell separately. Chezmoi does
  not replace shell startup files, aliases, or Home Manager shell integration.
- Ripgrep needs `RIPGREP_CONFIG_PATH` pointing to the deployed
  `${XDG_CONFIG_HOME:-$HOME/.config}/ripgrep/ripgreprc`; it does not discover that
  file automatically. Set the variable in the user's shell environment.
- Rebuild bat's theme cache with `bat cache --build` after installing/changing the
  theme files. Home Manager owns that activation hook on NixOS.
- Plain direnv works without the generated `direnv/lib/hm-nix-direnv.sh` loader.
  Nix-specific project environments need their own Nix/nix-direnv setup.
- tmux's base configuration works without plugins. Optional Catppuccin and
  resurrect installations use `tmux/plugins/catppuccin` and
  `tmux/plugins/resurrect` under the user's XDG config directory.
- Git's machine-local overrides belong in `git/config.local` beside the deployed
  config. This file is not managed by the adapters. GitHub credential integration
  expects `gh`, and the configured Git merge/diff tools expect Neovim.

The [portable validation report](modernization/portable-validation.md) states
what was tested and what still needs a fresh-machine trial.

## NixOS setup when deployment resumes

NixOS owns hardware and services. Integrated Home Manager owns user packages,
shell integration, and the deployed configuration in that home. Do not apply
chezmoi to the same files, and do not run standalone `home-manager switch`.

On the selected NixOS machine, create the live-file anchor before activation.
For the default anchor, from its checkout and as the intended user:

```sh
pixi run --locked just link-checkout "${XDG_DATA_HOME:-$HOME/.local/share}/nixfiles"
```

If `dotfiles.anchor` was overridden, pass that exact configured path instead.
The command discovers the current checkout and refuses to replace a real file
or directory. Moving the checkout requires refreshing this one anchor.

Use an explicit host for `check-host`, `plan`, `build`, and `diff`. Once a complete
build and its changes have been reviewed, the matching NixOS machine can use
`test-host <host>` for temporary activation, followed by `switch <host>` when
its operational checks succeed. These actions are not part of repository tests.
The recipes reject activation here and require the matching local hostname and
system store. Follow the [target validation and recovery procedure](modernization/baseline.md#validation-and-recovery)
for hardware checks, keeping a known-good generation, boot recovery, and rollback.

## Updates and recovery

`nh` is a Nix helper CLI providing build, switch, search, and cleanup commands.
This repository uses its cleanup service; the existing justfile workflows still
use Nix and nixos-rebuild directly. Shared cleanup runs weekly with
`--keep-since 7d --keep 2`. It retains recent generations and at least two
available generations even if both are older than a week. The old automatic
`nix-gc` schedule is disabled so a second cleanup policy cannot remove that
fallback. No checkout path is configured in nh.

Moon displays at most two system generations in systemd-boot. This boot-menu
limit controls presentation; the cleanup retention protects the underlying
generations. A first installation has only one until a second distinct system
generation exists. Keeping two generations does not itself establish that both
work. Retain and test a known-good generation during deployment.

Passwords can be supplied through `mkUser.hashedPasswordFile`, including an
agenix-decrypted hash. See [declarative password setup](modernization/user-profiles.md#declarative-passwords).
The [Moon build and testing guide](hosts/moon-testing.md) separates preparation
on this machine from checks on the actual device.

Update an explicit group, inspect the lock diff, and run the relevant checks:

```sh
pixi run --locked update-inputs nixpkgs home-manager
pixi run --locked check
pixi run --locked baseline
```

Update hardware, agenix, and Disko separately when appropriate. Keep their `follows` wiring
and one root nixpkgs revision. Flatpak updates remain a separate optional
`update-flatpak` task. None of these update recipes activates a system.
State versions describe compatibility choices; do not bump them with package pins.
The [input refresh report](modernization/input-refresh.md) records the current
accepted pins and upstream behavior changes.

A NixOS generation rollback does not revert live-linked source files or
application data. Restore the reviewed source revision as well when needed,
keeping unrelated local work intact. Preview configuration changes again before
reapplying. For missing files after relocation, check the NixOS anchor or rerun
chezmoi preview/apply from the new checkout; rebuilding packages cannot repair a
link to a missing external checkout.

Fresh-machine package installation, shell integration, complete NixOS builds,
boot/GPU/network testing, activation, and recovery drills remain deployment gates.
The temporary-home rehearsal does not claim those gates are complete.
