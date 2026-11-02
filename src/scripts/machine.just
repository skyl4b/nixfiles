# Update Flatpak applications independently of Nix and system activation
update-flatpak:
    #!/usr/bin/env bash
    set -euo pipefail
    flatpak update

# Connect this machine to Tailscale and display the sign-in URL
tailscale-up:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo tailscale up

# Copy the shared remaps to a keyboard and enable its autoload entry
[positional-arguments]
remap-keyboard device model="":
    #!/usr/bin/env bash
    set -euo pipefail
    python=(python3)
    if ! command -v python3 >/dev/null; then
        python=(just _nix shell --no-update-lock-file --inputs-from "$NIXFILES_CHECKOUT" nixpkgs#python3 -c python3)
    fi
    "${python[@]}" - "$NIXFILES_CHECKOUT/src/dotfiles/input-remapper/ergo_remaps.json" "$1" "$2" <<'PY'
    import json, os, sys, tempfile
    from pathlib import Path

    template, device, model = sys.argv[1:]
    model = model or device
    if not device.strip() or any(c in device for c in '\x00\n\r'):
        raise SystemExit('Supply the keyboard name shown by Input Remapper.')
    # Match Input Remapper's directory-name sanitization.
    folder = model.translate(str.maketrans({c: '_' for c in '/\\?%*:|"<>'}))
    if folder in ('', '.', '..') or any(c in folder for c in '\x00\n\r'):
        raise SystemExit('Invalid keyboard model name.')
    root = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'input-remapper-2'
    config_file = root / 'config.json'
    config = json.loads(config_file.read_text()) if config_file.exists() else {'version': '2.2.1'}
    if not isinstance(config, dict) or not isinstance(config.get('autoload', {}), dict):
        raise SystemExit('Expected an object with an autoload object in config.json; no files changed.')
    preset = json.loads(Path(template).read_text())
    config.setdefault('autoload', {})[device] = 'ergo_remaps'

    def save(path, value):
        data = (json.dumps(value, indent=4) + '\n').encode()
        if path.exists() and path.read_bytes() == data:
            return
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists():
            fd, backup = tempfile.mkstemp(prefix=path.name + '.', suffix='.bak', dir=path.parent)
            with os.fdopen(fd, 'wb') as stream:
                stream.write(path.read_bytes())
            print(f'Backup: {backup}')
        fd, temporary = tempfile.mkstemp(prefix='.' + path.name + '.', dir=path.parent)
        try:
            with os.fdopen(fd, 'wb') as stream:
                stream.write(data)
            os.replace(temporary, path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)

    preset_file = root / 'presets' / folder / 'ergo_remaps.json'
    save(preset_file, preset)
    save(config_file, config)
    print(f'Configured {device}: {preset_file}')
    print('Apply ergo_remaps in Input Remapper now, or reconnect the keyboard after your next desktop login.')
    PY
