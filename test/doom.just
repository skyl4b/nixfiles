# Exercise Doom bootstrap/dispatch and portable links in an isolated home
test-doom:
    #!/usr/bin/env bash
    set -euo pipefail
    python3 - <<'PY'
    import json, os, shutil, subprocess, tempfile, textwrap
    from pathlib import Path

    with tempfile.TemporaryDirectory(prefix='nixfiles-doom-') as temporary:
        root = Path(temporary)
        checkout = root / 'checkout with spaces'
        original = Path(os.environ['NIXFILES_CHECKOUT'])
        shutil.copytree(original / 'src/dotfiles/doom', checkout / 'src/dotfiles/doom')
        shutil.copytree(original / 'src/chezmoi/dot_config/doom', checkout / 'src/chezmoi/dot_config/doom')
        subprocess.run(['just', '_copy-justfiles', str(checkout)], check=True)
        home = root / 'home'
        home.mkdir()
        config = home / 'config with spaces'
        binaries = root / 'bin'
        binaries.mkdir()
        log = root / 'calls.jsonl'
        environment = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(config),
                           PATH=str(binaries) + os.pathsep + os.environ['PATH'], NIXFILES_DOOM_LOG=str(log),
                           NIXFILES_DOOM_TEST_GIT=shutil.which('git'))
        for key in ('EMACSDIR', 'DOOMDIR', 'EMACS'):
            environment.pop(key, None)
        doom = textwrap.dedent('''\
            #!/usr/bin/env python3
            import json, os, sys
            from pathlib import Path
            with Path(os.environ['NIXFILES_DOOM_LOG']).open('a') as stream:
                stream.write(json.dumps(['doom', sys.argv[1:], os.environ['EMACSDIR'], os.environ['DOOMDIR']]) + '\\n')
            ''')
        (root / 'doom-stub').write_text(doom)
        git = textwrap.dedent('''\
            #!/usr/bin/env python3
            import json, os, shutil, sys
            from pathlib import Path
            if sys.argv[1:2] != ['clone']:
                real_git = os.environ['NIXFILES_DOOM_TEST_GIT']
                os.execv(real_git, [real_git, *sys.argv[1:]])
            assert sys.argv[1:6] == ['clone', '--depth', '1', '--', 'https://github.com/doomemacs/core']
            with Path(os.environ['NIXFILES_DOOM_LOG']).open('a') as stream:
                stream.write(json.dumps(['git', sys.argv[1:]]) + '\\n')
            destination = Path(sys.argv[-1]) / 'bin'
            destination.mkdir(parents=True)
            shutil.copy(Path(__file__).parent.parent / 'doom-stub', destination / 'doom')
            (destination / 'doom').chmod(0o755)
            ''')
        (binaries / 'git').write_text(git)
        (binaries / 'emacs').write_text('#!/bin/sh\nexit 0\n')
        for file in binaries.iterdir():
            file.chmod(0o755)

        def run(*args, success=True):
            result = subprocess.run(['just', '--justfile', str(checkout / 'justfile'), *args],
                                    env=environment, capture_output=True, text=True)
            assert (result.returncode == 0) == success, result.stdout + result.stderr
            return result

        run('doom', 'doctor', success=False)
        run('doom-install', success=False)
        assert not log.exists(), 'Missing personal config must not trigger a clone'
        run('dotfiles-apply', str(home))
        # Portable deployment uses ~/.config; the custom XDG location is selected separately.
        config.mkdir()
        (config / 'doom').symlink_to(home / '.config/doom', target_is_directory=True)
        for file in ('init.el', 'config.el', 'packages.el'):
            assert (config / 'doom' / file).resolve() == checkout / 'src/dotfiles/doom' / file
        run('doom-install')
        run('doom-install')
        run('doom', 'sync', '--env', 'argument with spaces')
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        assert [call[0] for call in calls] == ['git', 'doom', 'doom', 'doom']
        assert calls[-1][1:] == [['sync', '--env', 'argument with spaces'], str(config / 'emacs'), str(config / 'doom')]
        assert calls[1][1] == ['install', '--no-config']
        before = {p.name: p.read_bytes() for p in (checkout / 'src/dotfiles/doom').iterdir()}
        for file in ('init.el', 'config.el', 'packages.el'):
            assert (original / 'src/dotfiles/doom' / file).read_bytes() == before[file]
        (checkout / 'src/dotfiles/doom/config.el').write_text(before['config.el'].decode() + '\n;; live edit\n')
        assert (config / 'doom/config.el').read_text().endswith(';; live edit\n')
        moved = root / 'checkout moved'
        shutil.move(checkout, moved)
        checkout = moved
        run('dotfiles-apply', str(home))
        assert (config / 'doom/config.el').resolve() == moved / 'src/dotfiles/doom/config.el'
        legacy = home / '.emacs.d'
        legacy.mkdir()
        (legacy / 'init.el').write_text('unrelated Emacs config\n')
        count = len(log.read_text().splitlines())
        run('doom-install', success=False)
        assert len(log.read_text().splitlines()) == count
        assert (legacy / 'init.el').read_text() == 'unrelated Emacs config\n'
        (home / '.emacs').write_text('legacy init\n')
        assert 'takes precedence' in run('doom-install', success=False).stderr
        (home / '.emacs').unlink()
        (legacy / 'bin').mkdir()
        shutil.copy(config / 'emacs/bin/doom', legacy / 'bin/doom')
        run('doom', 'doctor')
        assert json.loads(log.read_text().splitlines()[-1])[2] == str(legacy)
        environment['EMACSDIR'] = str(config / 'emacs')
        environment['DOOMDIR'] = str(config / 'doom')
        run('doom', 'doctor')
        assert json.loads(log.read_text().splitlines()[-1])[1] == ['doctor']
    print('Doom checks passed: personal links, live edits, relocation, bootstrap, repeat install, CLI arguments, and existing-config protection. No real Doom installation was changed.')
    PY

# Build Doom's Home Manager links and parse the personal Lisp using pinned Emacs
test-doom-nix:
    #!/usr/bin/env bash
    set -euo pipefail
    umask 077
    test_dir=$(mktemp -d "${TMPDIR:-/tmp}/nixfiles-doom-nix.XXXXXX")
    checkout="$test_dir/checkout with spaces"
    target="$test_dir/home"
    mkdir -p "$checkout/src/dotfiles" "$target"
    cp -R src/dotfiles/doom "$checkout/src/dotfiles/"
    just _copy-justfiles "$checkout"
    anchor="$target/.local/share/nixfiles"
    just --justfile "$checkout/justfile" link-checkout "$anchor"
    export NIXFILES_STORE="$NIXFILES_TEST_ROOT"
    eval_args=(--impure --file src/tests/doom.nix --argstr testHome "$target")
    just _nix eval "${eval_args[@]}" --json metadata >"$test_dir/metadata.json"
    jq -e --arg anchor "$anchor" '
        .anchor == $anchor and .generatedEmacs == false and
        .configFiles == {"doom/init.el":"doom/init.el", "doom/config.el":"doom/config.el", "doom/packages.el":"doom/packages.el"}
    ' "$test_dir/metadata.json" >/dev/null
    files=$(just _nix build "${eval_args[@]}" --no-link --print-out-paths files)
    for file in init.el config.el packages.el; do
        source=$(jq -r --arg file "doom/$file" '.sources[$file]' "$test_dir/metadata.json")
        [[ -L "$NIXFILES_TEST_ROOT$files/.config/doom/$file" ]]
        [[ "$(readlink "$NIXFILES_TEST_ROOT$source")" == "$anchor/src/dotfiles/doom/$file" ]]
    done
    just _nix shell "${eval_args[@]}" emacs -c emacs --quick --batch --eval '
      (progn
        (dolist (file command-line-args-left)
          (with-temp-buffer
            (insert-file-contents file)
            (emacs-lisp-mode)
            (check-parens)
            (goto-char (point-min))
            (while (progn (forward-comment (point-max)) (< (point) (point-max)))
              (read (current-buffer)))))
        (setq command-line-args-left nil)
        (princ "PASS: personal Doom files parse with pinned Emacs.\n"))' \
        "$checkout/src/dotfiles/doom/init.el" "$checkout/src/dotfiles/doom/config.el" "$checkout/src/dotfiles/doom/packages.el"
    printf 'PASS: built Doom Home Manager links; normal Doom owns its runtime.\nReport: %s\n' "$test_dir"
