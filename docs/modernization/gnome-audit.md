# GNOME audit and cleanup

Audited and updated on 2026-10-20 against the existing lockfile: GNOME Shell
**50.4**, GDM **50.2**, and Home Manager revision
`b74e23e34d3172802fdd60d4a1a01978f95e1898`. The shared GNOME module applies to
Jupiter and Moon. No live GNOME session or Surface hardware was tested.

## GTK appearance correction

[`src/home/default.nix`](../../src/home/default.nix) previously assigned the
legacy `Adwaita-dark` theme to GTK4. Home Manager generated an import of
`share/themes/Adwaita-dark/gtk-4.0/gtk.css`. Inspection of the pinned
`gnome-themes-extra-3.28` package confirms that file does not exist: the theme
contains only its index and GTK3 stylesheet. The explicit compatibility override
added during modernization was incorrect and is now removed.

`gtk.colorScheme` was also null. A GTK3 theme selection does not establish the
system dark preference followed by modern libadwaita applications
([upstream appearance documentation](https://gnome.pages.gitlab.gnome.org/libadwaita/doc/main/styles-and-appearance.html)).
The configuration now uses `gtk.gtk4.theme = null` and `gtk.colorScheme = "dark"`.
Generated GTK4 settings declare the native dark scheme, and dconf declares
`color-scheme = "prefer-dark"`. The legacy GTK3 theme is retained. This shared
home correction applies to Mars as well as the GNOME hosts.

## Tiling and extension activation

The user requires dynamic automatic tiling and selected
[O-Tiling](https://github.com/oliwebd/o-tiling), a Pop Shell fork. The existing
nixpkgs pin supplies release **2.11.03** (extension version **30**), whose metadata
lists GNOME 48, 49, and 50. No new input or package override is needed.

Pop Shell and Pop Launcher are removed. O-Tiling has no Pop Launcher dependency
in the inspected package. The original Pop Shell package also declared GNOME 50
compatibility; the audit's replacement recommendation concerned its maintenance
model, described in the [System76 statement](https://github.com/pop-os/shell/discussions/1728),
rather than a reproduced crash.

The GNOME module supplies unlocked system dconf defaults that enable
AppIndicator, Dash to Dock, Caffeine, and O-Tiling on fresh accounts. The user
database takes precedence, so users can change the enabled list and retain those
choices across rebuilds. Home Manager no longer writes this key on activation.
The selected AppIndicator 66, Dash to Dock 109, Caffeine 60, and O-Tiling 30
metadata all list GNOME 50. Mars does not inherit these GNOME extension settings.

O-Tiling uses its upstream settings without repository overrides. Automatic
tiling is already enabled by the pinned schema's default. Its default Vim-style
focus aliases include `Super+H` and `Super+L`, which overlap GNOME shortcuts.
Review these in the extension's preferences on the target machine. O-Tiling
contains shortcut conflict handling and restoration on disable; those runtime
paths still need live session testing.

The global `disable-user-extensions` setting is left unmanaged. Its upstream
default is already `false`; explicitly writing that value would reset a user's
global extension-disable choice on activation
([GNOME schema](https://github.com/GNOME/gnome-shell/blob/50.4/data/org.gnome.shell.gschema.xml.in)).

Useful default O-Tiling controls from the pinned schema:

| Shortcut | Action |
| --- | --- |
| `Super+Alt+Arrow` or `Super+H/J/K/L` | Focus another tiled window |
| `Super+T` | Toggle automatic tiling |
| `Super+F` | Toggle floating for the focused window |
| `Super+Return` | Enter interactive tiling mode |
| `Super+Shift+O` | Change split orientation |

## Package and integration cleanup

- GDM Settings 5.0 is removed. Its maintainer reports GDM 50 breakage and paused
  development ([announcement](https://github.com/gdm-settings/gdm-settings/issues/324)).
  GDM remains enabled. Future greeter customization should use NixOS settings
  and its greeter dconf profile.
- The redundant explicit GNOME Software package is removed. It remains installed
  once through the GNOME module's Flatpak integration.
- Ptyxis is removed and GNOME Console is retained as the standard desktop
  terminal. WezTerm is also supplied by the shared home modules.
- The unused GSConnect package selection is removed. Phone integration remains
  disabled on the GNOME hosts, with firewall policy unchanged.
- GNOME Network Displays remains available for Miracast. Device support needs
  separate testing.
- GNOME portals, keyring, Flatpak, and existing sharing-support modules are
  retained. Support-module flags do not by themselves establish that user
  sharing is active or reachable.

## Verification

The original settings are recorded in `/tmp/nixfiles-gnome-audit.json`; the
missing stylesheet was verified with the fetched theme package recorded in
`/tmp/nixfiles-gnome-theme-build.log`.

`/tmp/nixfiles-o-tiling-validation.json` records the initial three-host
configuration. Home package selections, compatibility versions, and firewall
policy are retained. The pinned O-Tiling package is checked with GJS against its
real compiled schema, using an in-memory settings backend. All configured keys,
values, automatic tiling, and the then-configured focus shortcuts pass
(`/tmp/nixfiles-o-tiling-schema.log`). These tests do not activate a desktop or
write settings to a real user profile.

Repository checks pass (`/tmp/nixfiles-o-tiling-check.log`), along with all 26
three-host baseline checks (`/tmp/nixfiles-baseline.OSfxxK/summary.md`). All host
warning lists are empty. Comparison with the preceding baseline confirms that
only the intended GNOME system package declarations change; other host-policy
observations and every home package selection remain unchanged.

The subsequent simplification removes Ptyxis, the O-Tiling settings overrides,
and the explicit global extension-disable setting. Focused evaluation is recorded
in `/tmp/nixfiles-gnome-simplified-validation.json`, with repository checks in
`/tmp/nixfiles-gnome-simplified-check.log`. Both pass. Comparison confirms that
Jupiter and Moon retain the four enabled extensions and WezTerm; only Ptyxis
and the requested dconf overrides are removed. Mars is unchanged. The full
baseline above predates this simplification and was not repeated.

GNOME Console was subsequently restored by removing its package exclusion.
Focused evaluation is recorded in `/tmp/nixfiles-gnome-console-validation.json`.

The extension list subsequently moved from Home Manager to
`programs.dconf.profiles.user.databases`, using its default writable user
database and no locks. If an earlier Home Manager configuration was activated,
its cleanup resets the formerly managed key once during this transition.
Subsequent activations leave the user's extension list alone. The dconf profile
is selected at login; log in again after first deploying the new profile
([GNOME profile documentation](https://help.gnome.org/system-admin-guide/dconf-profiles.html)).

Repository checks and three-host evaluation pass
(`/tmp/nixfiles-gnome-defaults-check.log` and
`/tmp/nixfiles-gnome-defaults-validation.json`). The generated system profile and
databases build successfully. An isolated temporary user database receives all
four default extensions, accepts a replacement list, retains it across private
D-Bus sessions and profile reload, and restores the defaults after a user reset
(`/tmp/nixfiles-gnome-defaults-runtime.log`). No real user settings were changed.
