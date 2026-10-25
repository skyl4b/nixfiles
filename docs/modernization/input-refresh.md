# Controlled input refresh

All four retained inputs are refreshed through the host-explicit workflow.
Nixpkgs and Home Manager were updated together first, followed by nixos-hardware
and agenix. The platform now evaluates as NixOS 26.11 pre-release. The original
unstable/master input choices remain; this does not select a stable release or
change any system or Home Manager state version.

| Input | Previous revision | Refreshed revision |
| --- | --- | --- |
| nixpkgs | `89c2b2330e73` | `fe13242281a67641c0102cdb1087f0ebe586c7df` |
| Home Manager | `d10a9b16b2a3` | `b74e23e34d3172802fdd60d4a1a01978f95e1898` |
| nixos-hardware | `899dc449bc64` | `60a624466c08787ee8303393b7d4752d1826f14f` |
| agenix | `fcdea2233974` | `847720f0e73a77ce6503b63fba6c357c742c28a7` |

The new lockfile SHA-256 is
`1f7f865907cf033fcac11bb27610c9e5de064a7d20f9d88e48e51cac955cb9cc`.
The pre-refresh lockfile and source snapshot are saved under
`/tmp/nixfiles-refresh-before/`, with the preceding workflow baseline included.

## Input graph

The graph shrinks from seven to five nodes, including the root: four direct
inputs share a single nixpkgs revision. The updated
[agenix flake](https://github.com/ryantm/agenix/blob/847720f0e73a77ce6503b63fba6c357c742c28a7/flake.nix)
no longer needs the Darwin, systems, or Home Manager inputs. The obsolete agenix
Home Manager override is removed. The updated nixos-hardware flake adds a
nixpkgs input; it now follows the root pin instead of retaining a second revision.

The Rust overlay/toolchain and unused Catppuccin input remain absent. No new
repository devShell or development dependency is added; Pixi remains unchanged.

## Compatibility changes

- Hyfetch's new Home Manager module declares a config-file entry even with empty
  settings, conflicting with the native file's ownership. Its package is now
  installed directly, as with Gitui and Zathura. The native JSON stays unchanged.
- GTK4 explicitly keeps the existing Adwaita theme behavior. Yazi explicitly
  keeps the `yy` shell wrapper. Home Manager's
  [26.05 state-version notes](https://github.com/nix-community/home-manager/blob/b74e23e34d3172802fdd60d4a1a01978f95e1898/docs/release-notes/rl-2605.md#state-version-changes)
  describe both changed defaults. Isolated Zsh test fixtures also retain their
  previous home-directory layout explicitly.
- Strict reverse-path filtering is retained using the canonical `"strict"`
  value, equivalent to the previous `true`. Mars keeps power-profiles-daemon
  and leaves system76-scheduler disabled until hardware testing. The
  [26.11 release notes](https://github.com/NixOS/nixpkgs/blob/fe13242281a67641c0102cdb1087f0ebe586c7df/nixos/doc/manual/release-notes/rl-2611.section.md)
  document the changed firewall and COSMIC power defaults.
- Deprecated `xorg.xhost` and the test-only `xorg.xorgserver` references use their
  canonical `xhost` and `xorg-server` names.
- Yazi 26.9.1 requires filetype rules with `url` patterns and the current indicator,
  help, and confirmation style fields. The vendored Catppuccin flavor is adapted
  using the [theme schema](https://yazi-rs.github.io/docs/configuration/theme/),
  retaining its palette, icons, highlighting assets, and licenses. Its editor
  binding uses `%h`, the current
  [hovered-path template](https://yazi-rs.github.io/docs/configuration/keymap/#shell),
  so filenames with spaces still reach the editor as one argument.

The terminal tests were adapted to current behavior: full tmux key tables avoid
version-dependent key filtering, WezTerm application diagnostics are separated
from Nix diagnostics, and the Yazi test emulator tolerates unsupported private
terminal probes. The Yazi test waits for help to close and confirms the actual
entered directory, rather than matching text already visible in the preview.
These changes keep the original behavioral checks meaningful.

## Observed host differences

Both hosts retain their disk/swap definitions, PRIME identifiers, explicit
hardware files, locale, user groups, configured service choices, firewall exceptions,
Tailscale settings, cache trust, and Nix policy. System and home compatibility
versions remain Jupiter 23.11, Mars 24.11, and Home Manager 23.11 on both hosts.
Mars's power stack was compared separately and remains unchanged.

The refresh intentionally accepts these upstream changes:

- Avahi wide-area discovery now defaults to disabled; local mDNS and its existing
  UDP exception remain enabled. The pinned
  [Avahi module](https://github.com/NixOS/nixpkgs/blob/fe13242281a67641c0102cdb1087f0ebe586c7df/nixos/modules/services/networking/avahi-daemon.nix)
  recommends that default. Reflector mode remains disabled.
- Updated kernel/NVIDIA modules add default initrd modules, blacklist `nova_core`,
  and change the graphics-library layout. NVIDIA CDI preparation now uses
  `udevadm settle`; the existing CDI service relationships remain. These require
  target-machine validation before deployment.
- Upstream desktop/support packages change: Jupiter's system list grows from
  291 to 301 entries, including thumbnailer/input-method/DBus changes and removal
  of default Geary. Mars grows from 256 to 271 entries, including new COSMIC core
  applications and support packages. This is not a deduplicated package count.
- Docker moves from 28.5.1 to 29.8.2. Other packages, locale archives, Qt library
  paths, and generated configuration references advance with the platform.
  Home Manager additionally exports `XDG_BIN_HOME` as the existing `.local/bin`.

Each home still declares 119 package entries. Aside from package/version changes,
`LanguageTool` and `unicode` become the canonical package identities `languagetool`
and `unicode-paracode`. Editor helpers stay global; the removed project compilers
and runtimes are not reintroduced. Neovim advances from 0.11.5 to 0.12.6 with its
private providers retained.

## Validation

Validated on 2026-10-19 using the writable relocated store:

| Check | Result and report |
| --- | --- |
| Portable checks, recipe lint, 45 Nix parses, application/link tests | PASS; `/tmp/nixfiles-refresh-portable-final.log` |
| Both host evaluations/build plans, Hyprland evaluation, flake check | 19/19 PASS; `/tmp/nixfiles-baseline.AU9b7L/summary.md` |
| Home Manager Git links/relocation/custom anchor | PASS; `/tmp/nixfiles-git-nix.0SKJJB/` |
| tmux/plugins and WezTerm config loader | PASS; `/tmp/nixfiles-terminals-nix.eyZEh0/` |
| Yazi navigation/plugin/editor/theme/live edits and direnv | PASS; `/tmp/nixfiles-yazi-direnv-nix.pdkp5o/` |
| Starship prompt and interactive Gitui | PASS; `/tmp/nixfiles-starship-gitui-nix.7sPjU2/` |
| Bat/cache, bottom, ripgrep, tealdeer | PASS; `/tmp/nixfiles-cli-tools-nix.bXsnLP/` |
| Zellij, Hyfetch, Zathura | PASS; `/tmp/nixfiles-desktop-tools-nix.LOCLhF/` |
| Tiny fixture builds and closure comparison | PASS; `/tmp/nixfiles-workflows-nix.i1hbpO/` |
| Neovim user init, Python execution, Node RPC, project PATH precedence | PASS; `/tmp/nixfiles-editor.KzPrNo/` |
| Agenix package install checks and CLI help | PASS; `/tmp/nixfiles-refresh-editor-cli-build.log`, `/tmp/nixfiles-editor.KzPrNo/agenix-help.txt` |

Both hosts report empty warning lists. Package identities, policy changes, and
unchanged hardware sources are recorded in `/tmp/nixfiles-refresh-comparison.json`;
full package identities are in `/tmp/nixfiles-refresh-package-identities.json`.
Successful evaluation and application tests do not constitute full system builds
or GPU/boot/network validation. No system, real home profile, Flatpak application,
or secret deployment was activated. Moon remains deferred until its deployment
and hardware details are supplied.
