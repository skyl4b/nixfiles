# Exercise keyboard registration without accessing input devices or the daemon
test-input-remapper:
    #!/usr/bin/env bash
    set -euo pipefail
    python3 - <<'PY'
    import json, os, shutil, subprocess, tempfile
    from pathlib import Path

    with tempfile.TemporaryDirectory(prefix='nixfiles-remapper-') as temporary:
        fixture = Path(temporary)
        checkout = fixture / 'checkout with spaces'
        source = checkout / 'src/dotfiles/input-remapper'
        source.mkdir(parents=True)
        original = Path(os.environ['NIXFILES_CHECKOUT'])
        subprocess.run(['just', '_copy-justfiles', str(checkout)], check=True)
        shutil.copy(original / 'src/dotfiles/input-remapper/ergo_remaps.json', source)
        environment = dict(os.environ, XDG_CONFIG_HOME=str(fixture / 'config with spaces'))
        root = Path(environment['XDG_CONFIG_HOME']) / 'input-remapper-2'
        root.mkdir(parents=True)
        config_file = root / 'config.json'
        config_file.write_text(json.dumps({'version': '2.2.0', 'autoload': {'Mouse': 'custom'}, 'custom': True}))

        def run(*args, success=True):
            result = subprocess.run(['just', '--justfile', str(checkout / 'justfile'), 'remap-keyboard', *args],
                                    env=environment, capture_output=True, text=True)
            assert (result.returncode == 0) == success, result.stdout + result.stderr

        device = 'SEMICO USB Keyboard'
        run(device)
        config = json.loads(config_file.read_text())
        assert config == {'version': '2.2.0', 'autoload': {'Mouse': 'custom', device: 'ergo_remaps'}, 'custom': True}
        preset_file = root / 'presets' / device / 'ergo_remaps.json'
        preset = json.loads(preset_file.read_text())
        assert preset == json.loads((source / 'ergo_remaps.json').read_text())
        assert all('origin_hash' not in event for rule in preset for event in rule['input_combination'])
        before = {p: p.read_bytes() for p in root.rglob('*') if p.is_file()}
        run(device)
        assert before == {p: p.read_bytes() for p in root.rglob('*') if p.is_file()}
        preset_file.write_text('[{"custom": true}]\n')
        run(device)
        assert any(p.read_text() == '[{"custom": true}]\n' for p in preset_file.parent.glob('*.bak'))
        run(device + ' 2', device)
        assert json.loads(config_file.read_text())['autoload'][device + ' 2'] == 'ergo_remaps'
        assert not (root / 'presets' / (device + ' 2')).exists()
        run('Keyboard / USB')
        assert (root / 'presets/Keyboard _ USB/ergo_remaps.json').exists()
        run('..', success=False)
        run('', success=False)
        config_file.write_text('{invalid')
        run('Unconfigured Keyboard', success=False)
        assert config_file.read_text() == '{invalid'
        assert not (root / 'presets/Unconfigured Keyboard').exists()
    print('Keyboard registration passed: copied preset, merged autoload, backups, idempotence, model aliases, and invalid-config preservation.')
    PY
