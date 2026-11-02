# Verify Proton agent units and socket selection without accessing real credentials
test-proton-ssh-agent-nix:
    #!/usr/bin/env bash
    set -euo pipefail
    umask 077
    test_dir=$(mktemp -d "${TMPDIR:-/tmp}/nixfiles-proton-agent.XXXXXX")
    target="$test_dir/home with spaces"
    mkdir -p "$target"
    export NIXFILES_STORE="$NIXFILES_TEST_ROOT"
    eval_args=(--impure --file src/tests/proton-ssh-agent.nix --argstr testHome "$target")
    files=$(just _nix build "${eval_args[@]}" --no-link --print-out-paths files)
    units=$(just _nix eval "${eval_args[@]}" --raw systemdUnits)
    just _nix shell "${eval_args[@]}" runtime -c python3 - "$target" "$files" "$units" <<'PY'
    import configparser, os, shutil, subprocess, sys
    from pathlib import Path

    home, files, systemd_units = map(Path, sys.argv[1:])
    shutil.copytree(files, home, dirs_exist_ok=True, symlinks=True)
    for directory in [home, *home.rglob('*')]:
        if directory.is_dir() and not directory.is_symlink():
            directory.chmod(0o700)
    runtime = home.parent / 'runtime'
    runtime.mkdir(mode=0o700)
    environment = dict(os.environ, HOME=str(home), XDG_RUNTIME_DIR=str(runtime),
                       XDG_CONFIG_HOME=str(home / '.config'), ZDOTDIR=str(home))
    environment.pop('__HM_SESS_VARS_SOURCED', None)
    environment.pop('__HM_ZSH_SESS_VARS_SOURCED', None)
    expected = str(runtime / 'proton-pass-agent')
    for previous, connection, wanted in [
        ('', '', expected),
        ('/tmp/another-local-agent', '', expected),
        ('/tmp/forwarded-agent', 'client 1234 server 22', '/tmp/forwarded-agent'),
        ('', 'client 1234 server 22', expected),
    ]:
        env = dict(environment, SSH_AUTH_SOCK=previous, SSH_CONNECTION=connection)
        commands = [
            ['zsh', '-c', 'printf "%s" "$SSH_AUTH_SOCK"'],
            ['zsh', '-l', '-c', 'printf "%s" "$SSH_AUTH_SOCK"'],
        ]
        for command in commands:
            result = subprocess.run(command, env=env, capture_output=True, text=True)
            assert result.returncode == 0 and result.stdout == wanted and not result.stderr, (command, result)

    units = home / '.config/systemd/user'
    for suffix in ('service', 'socket'):
        assert (units / f'gcr-ssh-agent.{suffix}').resolve() == Path('/dev/null')
    unit = configparser.ConfigParser(interpolation=None)
    unit.read(units / 'proton-pass-agent.service')
    assert unit['Install']['WantedBy'] == 'default.target'
    assert unit['Unit']['StartLimitIntervalSec'] == '0'
    environment_file = home / '.config/environment.d/10-home-manager.conf'
    assert 'PROTON_PASS_LINUX_KEYRING=dbus' in environment_file.read_text().splitlines()
    assert unit['Service']['Restart'] == 'on-failure'
    assert 'ssh-agent start --socket-path %t/proton-pass-agent' in unit['Service']['ExecStart']
    assert '--create-new-identities' not in unit['Service']['ExecStart']
    help_text = subprocess.run(['pass-cli', 'ssh-agent', 'start', '--help'], env=environment,
                               check=True, capture_output=True, text=True).stdout
    assert '--socket-path' in help_text
    environment['SYSTEMD_UNIT_PATH'] = f'{units}:{systemd_units}'
    subprocess.run(['systemd-analyze', '--user', '--generators=no', '--man=no', 'verify',
                    str(units / 'proton-pass-agent.service'), str(units / 'set-SSH_AUTH_SOCK.service')],
                   env=environment, check=True)
    masked = subprocess.run(['systemd-analyze', '--user', '--generators=no', '--man=no', 'verify',
                             str(units / 'gcr-ssh-agent.service')], env=environment, capture_output=True, text=True)
    assert masked.returncode != 0 and 'masked' in masked.stderr, masked
    assert not (units / 'proton-pass-ssh-agent.service').exists()
    print('PASS: Home Manager agent unit, GCR masks, login startup/retries, pinned CLI options, Zsh socket selection, and preserved SSH agent forwarding. No credentials accessed.')
    PY
    printf 'Report: %s\n' "$test_dir"
