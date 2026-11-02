# Test installer dispatch with simulated NixOS detection and stubbed privileged tools
test-install-workflows:
    #!/usr/bin/env bash
    set -euo pipefail
    python3 - <<'PY'
    import json, os, shlex, subprocess, tempfile
    from pathlib import Path

    with tempfile.TemporaryDirectory(prefix='nixfiles-install-workflows-') as temporary:
        fixture = Path(temporary)
        checkout = fixture / 'checkout with spaces'
        host = checkout / 'src/hosts/probe'
        host.mkdir(parents=True)
        (host / 'default.nix').write_text('{ ... }: {}\n')
        marker = fixture / 'NIXOS'
        # Only the disposable copy sees a simulated NixOS marker. Production has no bypass.
        source = Path(os.environ['NIXFILES_CHECKOUT']) / 'justfile'
        subprocess.run(['just', '_copy-justfiles', str(checkout)], check=True)
        for commands in (checkout / 'src/scripts').glob('*.just'):
            commands.write_text(commands.read_text().replace('/etc/NIXOS', shlex.quote(str(marker))))
        environment = dict(os.environ, NIXFILES_STORE='daemon',
                           GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL='/dev/null')
        subprocess.run(['git', 'init', '-q', '--template=', str(checkout)], env=environment, check=True)
        binaries = fixture / 'bin'
        binaries.mkdir()
        stub = binaries / 'stub'
        stub.write_text('''#!/usr/bin/env python3
    import json, os, sys
    from pathlib import Path
    name, args = Path(sys.argv[0]).name, sys.argv[1:]
    with open(os.environ['NIXFILES_INSTALL_LOG'], 'a') as log:
        log.write(json.dumps([name, *args]) + '\\n')
    failure = os.environ.get('NIXFILES_INSTALL_FAIL')
    if name == 'nix':
        if 'build' in args:
            if failure == 'build': sys.exit(1)
            print('/nix/store/00000000000000000000000000000000-fixture-disko')
        elif 'eval' in args:
            if any('anchor = config.home-manager' in arg for arg in args):
                print(json.dumps({'home': '/home/probe', 'anchor': '/home/probe/.local/share/nixfiles'}))
            else:
                print('/dev/fixture-only')
        else:
            sys.exit(1)
    elif name == 'sudo':
        if args == ['/nix/store/00000000000000000000000000000000-fixture-disko']:
            sys.exit(0)  # Never execute a Disko script.
        if args and args[0] == 'nixos-generate-config':
            os.execvp(args[0], args)
        if args[:2] == ['bash', '-s']:
            os.execvp(args[0], args)  # The script only sees disposable paths and this test user's UID/GID.
        sys.exit(1)
    elif name == 'mountpoint':
        sys.exit(1 if failure == 'mount' else 0)
    elif name == 'nixos-generate-config':
        if failure == 'scan': sys.exit(1)
        print('invalid nix {' if failure == 'invalid' else
              '{ ... }: { boot.initrd.availableKernelModules = [ "nvme" ]; }')
    else:
        sys.exit(1)
    ''')
        stub.chmod(0o755)
        for name in ['nix', 'sudo', 'mountpoint', 'nixos-generate-config']:
            (binaries / name).symlink_to(stub)
        log = fixture / 'calls.jsonl'
        environment.update(PATH=str(binaries) + os.pathsep + environment['PATH'], NIXFILES_INSTALL_LOG=str(log))

        def run(*args, success=True, stdin='', **changes):
            result = subprocess.run(['just', '--justfile', str(checkout / 'justfile'), *args],
                                    env=dict(environment, **changes), input=stdin, capture_output=True, text=True)
            assert (result.returncode == 0) == success, result.stdout + result.stderr

        def calls():
            return [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []

        run('disko', 'probe', success=False)
        run('generate-hardware', 'probe', success=False)
        assert calls() == []
        marker.touch()
        run('disko', 'missing', success=False)
        run('disko', '../probe', success=False)
        run('disko', 'probe', success=False, NIXFILES_STORE=str(fixture / 'scratch'))
        assert calls() == []
        run('disko', 'probe', success=False, NIXFILES_INSTALL_FAIL='build')
        assert not any(call[0] == 'sudo' for call in calls())
        log.unlink()
        for answer in ['', '\n', 'no\n', 'anything\n']:
            run('disko', 'probe', stdin=answer, success=False)
            assert not any(call[0] == 'sudo' for call in calls())
        log.unlink()
        run('disko', 'probe', stdin='YES\n')
        recorded = calls()
        build = next(call for call in recorded if call[0] == 'nix' and 'build' in call)
        assert '--no-update-lock-file' in build and '--no-link' in build
        assert build[build.index('--max-jobs') + 1] == '1'
        assert build[build.index('--cores') + 1] == '2'
        assert build[-1] == '.#nixosConfigurations.probe.config.system.build.diskoScript'
        assert recorded[-1] == ['sudo', '/nix/store/00000000000000000000000000000000-fixture-disko']
        root = fixture / 'mounted target with spaces'
        root.mkdir()
        destination = host / 'hardware-configuration.nix'
        run('generate-hardware', 'probe', 'relative', success=False)
        for failure in ['mount', 'scan', 'invalid']:
            run('generate-hardware', 'probe', str(root), success=False, NIXFILES_INSTALL_FAIL=failure)
            assert not destination.exists() and not list(host.glob('.hardware-configuration.*'))
        run('generate-hardware', 'probe', str(root))
        assert '"nvme"' in destination.read_text()
        assert ['nixos-generate-config', '--root', str(root), '--no-filesystems', '--show-hardware-config'] in calls()
        subprocess.run(['git', '-C', str(checkout), 'ls-files', '--error-unmatch',
                        'src/hosts/probe/hardware-configuration.nix'], env=environment, check=True, capture_output=True)
        before = destination.read_bytes()
        run('generate-hardware', 'probe', str(root), success=False)
        assert destination.read_bytes() == before

        # Copy a real Git working tree, including an uncommitted hardware module.
        (checkout / '.gitignore').write_text('.pixi/\n')
        (checkout / 'README.md').write_text('fixture\n')
        (checkout / 'deleted.txt').write_text('deleted after commit\n')
        subprocess.run(['git', '-C', str(checkout), 'add', 'README.md', '.gitignore', 'deleted.txt'],
                       env=environment, check=True)
        subprocess.run(['git', '-C', str(checkout), '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.test',
                        'commit', '-qm', 'fixture'], env=environment, check=True)
        (checkout / 'deleted.txt').unlink()
        (checkout / 'local.txt').write_text('uncommitted local edit\n')
        (checkout / '.pixi').mkdir()
        (checkout / '.pixi/cache.bin').write_text('do not copy\n')
        (root / 'etc').mkdir()
        (root / 'etc/passwd').write_text(f'probe:x:{os.getuid()}:{os.getgid()}::/home/probe:/bin/sh\n')
        (root / 'home/probe').mkdir(parents=True)
        run('install-checkout', 'probe', 'probe', str(root))
        installed = root / 'home/probe/Projects/nixfiles'
        anchor = root / 'home/probe/.local/share/nixfiles'
        assert installed.is_dir() and (installed / '.git').is_dir()
        assert subprocess.check_output(['just', '--justfile', str(installed / 'justfile'), '--summary'], env=environment) == subprocess.check_output(['just', '--justfile', str(checkout / 'justfile'), '--summary'], env=environment)
        assert (installed / 'src/hosts/probe/hardware-configuration.nix').read_bytes() == before
        assert (installed / 'local.txt').read_text() == 'uncommitted local edit\n'
        assert not (installed / '.pixi').exists() and not (installed / 'deleted.txt').exists()
        assert os.readlink(anchor) == '/home/probe/Projects/nixfiles'
        assert installed.stat().st_uid == os.getuid() and anchor.lstat().st_gid == os.getgid()
        for argument in [['rev-parse', 'HEAD'], ['symbolic-ref', '--short', 'HEAD']]:
            original = subprocess.check_output(['git', '-C', str(checkout), *argument], env=environment)
            copied = subprocess.check_output(['git', '-C', str(installed), *argument], env=environment)
            assert original == copied
        run('install-checkout', 'probe', 'probe', str(root), success=False)
        run('install-checkout', 'probe', 'missing', str(root), success=False)
        custom = '/srv/checkout with spaces'
        run('install-checkout', 'probe', 'probe', str(root), custom)
        assert (root / custom.lstrip('/') / 'local.txt').exists() and os.readlink(anchor) == custom
        anchor.unlink()
        anchor.mkdir()
        run('install-checkout', 'probe', 'probe', str(root), '/srv/another', success=False)
        assert not (root / 'srv/another').exists()
        anchor.rmdir()
        escape = fixture / 'outside target'
        escape.mkdir()
        (root / 'symlink-parent').symlink_to(escape)
        run('install-checkout', 'probe', 'probe', str(root), '/symlink-parent/checkout', success=False)
        assert not list(escape.iterdir())
        module = fixture / 'optional hardware'
        module.mkdir()
        (module / 'default.nix').write_text((source.parent / 'src/hosts/moon/default.nix').read_text())
        expression = '''{ directory }: let host = import (builtins.toPath (directory + "/default.nix")) {
          lib.optional = condition: value: if condition then [ value ] else [];
          inputs.agenix.nixosModules.default = /dev/null;
          inputs.disko.nixosModules.disko = /dev/null;
          config = {}; pkgs = {};
        }; in map toString host.imports'''

        def imports():
            result = subprocess.run(['nix-instantiate', '--store', 'dummy://', '--eval', '--strict', '--json', '--expr', expression,
                                     '--argstr', 'directory', str(module)], env=environment,
                                    capture_output=True, text=True)
            assert result.returncode == 0, result.stdout + result.stderr
            return json.loads(result.stdout)

        without_hardware = imports()
        (module / 'hardware-configuration.nix').write_text('{ ... }: {}\n')
        assert imports() == without_hardware + [str(module / 'hardware-configuration.nix')]
    print('Installer workflows passed: guards, Disko confirmation/cancellation, hardware generation/import, and checkout installation with Git history, local edits, cache exclusion, ownership, and anchor protection. No real disks or privileged tools used.')
    PY
