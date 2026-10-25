# Keyboard remaps

Input Remapper is enabled on all hosts, including its reconnect rules. Skylab's
desktop autostart loads the registered presets at login. No keyboard is
registered automatically: run the copy command once for each keyboard model.

The shared preset lives in `src/dotfiles/input-remapper/ergo_remaps.json`. It
preserves the supplied mappings, with the hardware-specific `origin_hash`
removed. The pinned Input Remapper 2.2.1 resolves missing hashes against the
selected device when starting injection. Its native format and device-specific
autoload are described in the [upstream usage guide](https://github.com/sezanzeb/input-remapper/blob/2.2.1/readme/usage.md).

## Register a keyboard

Find the keyboard's name in Input Remapper's device selector, or list devices:

```sh
sudo input-remapper-control --list-devices
```

From the repo checkout, run as your normal desktop user:

```sh
just remap-keyboard "SEMICO USB Keyboard"
```

For the built-in keyboard from the supplied configuration:

```sh
just remap-keyboard "AT Translated Set 2 keyboard"
```

The command copies the preset into your writable
`$XDG_CONFIG_HOME/input-remapper-2/presets/<keyboard>/ergo_remaps.json` (normally
under `~/.config`) and adds or updates only that keyboard's `autoload` entry in
`config.json`. Other preferences and device entries are preserved. Changed files
receive uniquely named `.bak` copies next to them; identical repeated runs do
not rewrite files or create more backups.

`just` is included in both user profiles. If Python is absent from your PATH,
the recipe runs it through Nix using this repository's pinned nixpkgs input.
Pixi is not required; Python does not need to be installed globally. On the
current Ubuntu development machine, `pixi shell --locked` supplies the tools
before running the same `just` command.

The command does not start injection. To apply immediately, open Input Remapper,
select that keyboard and `ergo_remaps`, then press Apply. This also tells the
daemon about the updated user configuration. Otherwise, log out and back in;
the desktop autostart loads the new configuration. Registered devices can then
autoload when reconnected. Simply reconnecting before the daemon has loaded
the updated configuration is insufficient.

The copied files remain editable in the GUI. Running the command again restores
the repository's preset, backing up any local changes. Changes to the shared
template do not silently replace already copied presets.

If two identical keyboards appear as separate groups, supply the shared model
name as the second argument so both groups use the correct preset directory:

```sh
just remap-keyboard "SEMICO USB Keyboard 2" "SEMICO USB Keyboard"
```

## Preserved behavior

| Input | Output |
| --- | --- |
| Tap Caps Lock | Escape |
| Hold Caps Lock | Control, using the supplied mod-tap behavior |
| Escape | Caps Lock |
| Tap right Alt / AltGr | Compose |
| Hold AltGr with N/E/I/O in Colemak-DH | Left/down/up/right |

The four navigation inputs are physical J/K/L/semicolon on a US QWERTY keyboard,
codes 36/37/38/39. They become N/E/I/O with the configured Colemak-DH layout.
The additional supplied Caps + physical H-position Backspace mapping is retained
unchanged; it does not select the logical Colemak-DH H key.

Remapping occurs below the desktop's layout processing. Keep Colemak-DH selected
in GNOME/COSMIC, and use a keyboard that sends the expected physical US keycodes.
A keyboard already implementing Colemak in its firmware may need its own preset
to avoid applying the layout twice.

## Check on the installed host

After activating the configuration, log out and back in to enable the new
desktop autostart entry. Check `systemctl status input-remapper`, then test the
registered keyboard's Caps/Esc, held modifiers, Compose, and navigation. Unplug
and reconnect it and repeat the checks. No input events are intercepted during
repository validation; physical injection and reconnect behavior require the
actual host.

Stop a device's mapping in the GUI before editing it. Remove its `autoload`
entry or turn off Autoload in the GUI if you no longer want it applied.
