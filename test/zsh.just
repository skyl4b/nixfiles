# Exercise generated Zsh startup, plugins, tool hooks, and history in a disposable home
test-zsh-nix:
    #!/usr/bin/env bash
    set -euo pipefail
    umask 077
    test_dir=$(mktemp -d "${TMPDIR:-/tmp}/nixfiles-zsh.XXXXXX")
    target="$test_dir/home with spaces"
    checkout="$test_dir/checkout with spaces"
    mkdir -p "$target/.local/share" "$checkout/src/dotfiles"
    cp -R src/dotfiles/zsh src/dotfiles/starship src/dotfiles/direnv "$checkout/src/dotfiles/"
    ln -s "$checkout" "$target/.local/share/nixfiles"
    export NIXFILES_STORE="$NIXFILES_TEST_ROOT"
    eval_args=(--impure --file src/tests/zsh.nix --argstr testHome "$target")
    files=$(just _nix build "${eval_args[@]}" --no-link --print-out-paths files)
    runtime=$(just _nix build "${eval_args[@]}" --no-link --print-out-paths runtime)
    just _nix shell "${eval_args[@]}" runtime -c python3 - "$target" "$files" "$runtime" <<'PY'
    import os, shutil, subprocess, sys
    from pathlib import Path
    import pexpect

    home, files, runtime = map(Path, sys.argv[1:])
    shutil.copytree(files, home, dirs_exist_ok=True, symlinks=True)
    # Store directories are read-only; the deployed home must remain writable.
    for directory in [home, *home.rglob('*')]:
        if directory.is_dir() and not directory.is_symlink():
            directory.chmod(0o700)
    environment = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / '.config'),
                       XDG_CACHE_HOME=str(home / '.cache'), XDG_STATE_HOME=str(home / '.local/state'),
                       XDG_DATA_HOME=str(home / '.local/share'), NIX_PROFILES=str(runtime),
                       TERM='xterm-256color', ZDOTDIR=str(home))
    environment.pop('__HM_SESS_VARS_SOURCED', None)
    config = home / '.config/zsh/config.zsh'
    assert config.resolve() == (home / '.local/share/nixfiles/src/dotfiles/zsh/config.zsh').resolve()

    with (home.parent / 'interactive.log').open('w') as log:
        shell = pexpect.spawn('zsh', ['-i'], env=environment, encoding='utf-8', timeout=30)
        shell.logfile = log
        shell.sendline('print -r -- NIXFILES_READY')
        shell.expect(r'\r\nNIXFILES_READY\r\n')
        checks = [
            '(( $+functions[compdef] ))',
            '(( $+functions[_zsh_autosuggest_start] ))',
            '(( $+functions[_zsh_highlight] ))',
            '(( $+functions[prompt_starship_precmd] ))',
            '(( $+functions[_direnv_hook] ))',
            '(( $+functions[z] && $+functions[zi] ))',
            '(( $+functions[fzf-history-widget] ))',
            '[[ -o SHARE_HISTORY && -o HIST_IGNORE_ALL_DUPS && -o INTERACTIVE_COMMENTS ]]',
            '[[ $HISTFILE == "$XDG_STATE_HOME/zsh/history" ]]',
            '[[ $ZDOTDIR == "$XDG_CONFIG_HOME/zsh" ]]',
            '(( ${fpath[(I)*/share/zsh/site-functions]} ))',
        ]
        checks = ' && '.join(f'(if {check}; then :; else print -r -- NIXFILES_CHECK_FAILED_{index}; false; fi)'
                            for index, check in enumerate(checks))
        shell.sendline(f'if {checks}; then print -r -- NIXFILES_PASS; else print -r -- NIXFILES_FAIL; fi')
        shell.expect(r'\r\nNIXFILES_(PASS|FAIL)\r\n')
        assert shell.match.group(1) == 'PASS', 'See interactive.log for failed startup check'
        shell.sendline('print -r -- shared-history-probe')
        shell.expect(r'\r\nshared-history-probe\r\n')
        shell.sendline('exit')
        shell.expect(pexpect.EOF)
        shell.close()
        assert shell.exitstatus == 0

    history = home / '.local/state/zsh/history'
    assert 'shared-history-probe' in history.read_text()
    assert list((home / '.cache/zsh').glob('zcompdump-*'))
    assert not (home / '.zsh_history').exists()
    assert not (home / '.config/zsh/.zcompdump').exists()
    with config.open('a') as stream:
        stream.write('\nexport NIXFILES_LIVE_ZSH=live-edit\n')
    probe = subprocess.run(['zsh', '-i', '-c', '[[ $NIXFILES_LIVE_ZSH == live-edit ]]'],
                           env=environment, capture_output=True, text=True)
    assert probe.returncode == 0, probe.stdout + probe.stderr
    probe = subprocess.run(['zsh', '-c', 'print -r -- "${NIXFILES_LIVE_ZSH-unset}"'],
                           env=environment, capture_output=True, text=True)
    assert probe.returncode == 0 and probe.stdout == 'unset\n' and not probe.stderr, probe
    print('PASS: interactive startup, completion, both plugins, Starship/direnv/fzf/zoxide hooks, XDG history/cache, live edits, and quiet noninteractive startup.')
    PY
    printf 'Report: %s\n' "$test_dir"
