# Shared tmux and Ghostty configuration

tmux and Ghostty use native configuration under `src/dotfiles/`. Home Manager
and chezmoi link to the same files, so edits remain live and the checkout can
move without hardcoded paths. Ghostty replaces the former WezTerm home module,
package, and portable configuration.

## Sources and ownership

| Source | Purpose |
| --- | --- |
| `src/dotfiles/tmux/tmux.conf` | tmux settings, bindings, theme options, optional plugin loading |
| `src/dotfiles/ghostty/config` | Ghostty settings supplied by the user |
| `src/modules/home/tmux.nix` | tmux/xsel packages, socket environment, config and plugin links |
| `src/modules/home/ghostty.nix` | Ghostty package, shell/systemd integration, font and config link |
| `src/chezmoi/dot_config/{tmux,ghostty}/symlink_*.tmpl` | Non-NixOS config links |
| `src/tests/terminal-pilot.nix` | Isolated Home Manager file tree and pinned test executables |

The shared home imports both modules for the minimal and complete profiles.
Home Manager links through the configurable `dotfiles.anchor`; refresh that
local pointer after moving the checkout. Chezmoi resolves files relative to its
source directory; reapply after a move. Its adapters use `~/.config`.

The pinned Home Manager tmux module always generates `tmux.conf` when enabled,
so the native module installs the binary directly. It retains `TMUX_TMPDIR`,
selecting `$XDG_RUNTIME_DIR` or `/run/user/$(id -u)`, and `xsel` for the existing
copy-mode binding. Clipboard access still needs a working X display.

## Ghostty settings

The native config contains exactly:

```ini
font-family = Cascadia Code NF

background-opacity = 0.9
background-blur = true
```

The module installs `cascadia-code`, including the `Cascadia Code NF` family.
Home Manager's Ghostty settings remain empty so its generator does not compete
with the live config link. Shell integration and Linux systemd integration use
the upstream module defaults. Bat syntax installation is disabled because that
feature also generates bat settings, which already have a native config owner.

Blur depends on the desktop/compositor; the setting alone does not enable GNOME
blur. See [Ghostty's background-blur reference](https://ghostty.org/docs/config/reference#background-blur).
GNOME Console remains available as the desktop's standard terminal.

## tmux settings and plugins

Core settings formerly generated from Nix are now in the native file: `C-Space`
prefix, numbering from one, vi keys, mouse support, 24-hour clock, aggressive
resize, 10,000-line history, and the existing confirmation-free kill bindings.
The existing pane/navigation, clipboard, truecolor, passthrough, and timing
settings remain. The reload binding and plugin loader use
`${XDG_CONFIG_HOME:-$HOME/.config}`.

Home Manager links the pinned plugin directories at:

```text
$XDG_CONFIG_HOME/tmux/plugins/catppuccin/
$XDG_CONFIG_HOME/tmux/plugins/resurrect/
```

The shared config loads their executable entry points if present. It contains no
Nix store paths and also works without plugins. On another operating system,
supply tmux and `xsel`, and install compatible plugins at these paths when
desired. Chezmoi owns only the two native terminal config links; it does not
download plugins or install applications.

The old configuration loaded two different Catppuccin versions, through the
Catppuccin module and the explicit nixpkgs plugin list. This migration uses the
explicit nixpkgs plugin once: Catppuccin 2.1.3 from the existing lockfile. The
resurrect plugin and its `S`/`R` save/restore bindings retain their pinned version.

Several old theme options were ignored by Catppuccin 2.x. Their intended behavior
is expressed using its supported API:

| Previous setting | Current setting |
| --- | --- |
| `@catppuccin_flavour` | `@catppuccin_flavor`, Mocha |
| Custom window separators | `@catppuccin_window_status_style custom` plus the existing separators |
| `@catppuccin_window_default_text` | `@catppuccin_window_text`, `#W` |
| `@catppuccin_window_current_background` | `@catppuccin_window_current_number_color`, `#313244` |
| `@catppuccin_status_modules_right session` | Explicit `status-right` using the session format |

Removed fill/inversion options are covered by the plugin's current color-based
defaults. These changes make the intended separators and window names effective;
they are not a claim of visual parity with the previous overlapping themes.
The pinned plugin's README and option definitions were checked directly while
making this translation.

## Verification

Run the recipes directly with `just`. On the current Ubuntu preparation host,
enter `pixi shell --locked` first to supply development tools:

```sh
just check
just test-terminals-nix
```

`check` applies chezmoi into a temporary home, verifies terminal symlinks, runs a
private tmux server, and checks live edits and relocation. The Nix recipe builds
Home Manager's file tree, inspects package and shell integration, relocates the
checkout, and loads the pinned tmux plugins. It runs Ghostty's headless
`+validate-config` against the copied configuration and checks that fontconfig
resolves `Cascadia Code NF` using only the declared font package.

The complete `just test-portable-nix` rehearsal also validates Ghostty. No Home
Manager activation or graphical terminal session is performed. Font rendering,
opacity, blur, clipboard access, and Moon's hardware require target testing.
