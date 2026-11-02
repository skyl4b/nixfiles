# Verify shared Yazi/direnv files and chezmoi links in a temporary home
test-yazi-direnv:
    #!/usr/bin/env bash
    set -euo pipefail
    umask 077
    test_dir=$(mktemp -d "${TMPDIR:-/tmp}/nixfiles-yazi-direnv.XXXXXX")
    checkout="$test_dir/checkout one"
    target="$test_dir/home"
    mkdir -p "$checkout/src" "$target"
    cp -R src/dotfiles src/chezmoi "$checkout/src/"
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git init -q --template= "$checkout"
    touch "$test_dir/chezmoi.toml"
    chez() {
        chezmoi --source "$checkout/src/chezmoi" --working-tree "$checkout" \
            --destination "$target" --config "$test_dir/chezmoi.toml" \
            --cache "$test_dir/cache" --persistent-state "$test_dir/state.boltdb" --no-tty "$@"
    }
    chez init
    chez apply
    chez verify
    files=(direnv/direnv.toml direnv/direnvrc yazi/yazi.toml yazi/keymap.toml yazi/theme.toml
        yazi/plugins/smart-enter.yazi yazi/flavors/catppuccin-mocha.yazi)
    for file in "${files[@]}"; do
        [[ -L "$target/.config/$file" ]]
        [[ "$(readlink -f "$target/.config/$file")" == "$checkout/src/dotfiles/$file" ]]
    done
    shellcheck "$target/.config/direnv/direnvrc"
    luac -p "$target/.config/yazi/plugins/smart-enter.yazi/main.lua"
    python - "$target/.config" <<'PY'
    import plistlib, sys, tomllib
    from pathlib import Path
    config = Path(sys.argv[1])
    for path in config.rglob('*.toml'):
        tomllib.loads(path.read_text())
    flavor = config / 'yazi/flavors/catppuccin-mocha.yazi'
    tomllib.loads((flavor / 'flavor.toml').read_text())
    assert plistlib.loads((flavor / 'tmtheme.xml').read_bytes())['settings']
    assert 'MIT License' in (flavor / 'LICENSE').read_text()
    assert 'MIT License' in (flavor / 'LICENSE-tmtheme').read_text()
    PY
    mv "$checkout" "$test_dir/checkout moved"
    checkout="$test_dir/checkout moved"
    chez apply
    chez verify
    for file in "${files[@]}"; do [[ -e "$target/.config/$file" ]]; done
    printf '\n# live edit probe\n' >> "$target/.config/direnv/direnv.toml"
    [[ "$(tail -1 "$checkout/src/dotfiles/direnv/direnv.toml")" == '# live edit probe' ]]
    if grep -R -n '/nix/store/' "$checkout/src/dotfiles/yazi" "$checkout/src/dotfiles/direnv"; then
        printf 'Portable config contains a store path.\n' >&2; exit 1
    fi
    printf 'PASS: shared Yazi/direnv links, config syntax, theme assets, live edits, and relocation.\nReport: %s\n' "$test_dir"

# Run pinned applications against test-only configuration and project files
_test-yazi-direnv:
    #!/usr/bin/env bash
    set -euo pipefail
    python - <<'PY'
    import hashlib, os, subprocess, time
    from pathlib import Path
    import pexpect
    import pyte

    root = Path(os.environ['NIXFILES_CLI_TEST_DIR'])
    config = Path(os.environ['NIXFILES_CLI_CONFIG'])
    root.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.update(XDG_CONFIG_HOME=str(config), XDG_CACHE_HOME=str(root/'cache'),
               XDG_DATA_HOME=str(root/'data'), XDG_STATE_HOME=str(root/'state'),
               DIRENV_CONFIG=str(config/'direnv'), YAZI_CONFIG_HOME=str(config/'yazi'),
               TERM='xterm-256color')

    def run(*args, cwd=None, check=True):
        result = subprocess.run(args, cwd=cwd, env=env, text=True, capture_output=True)
        assert not check or result.returncode == 0, (args, result.stdout, result.stderr)
        return result

    # Home Manager supplies nix-direnv; portable chezmoi deployment omits it.
    nix_loader = config/'direnv/lib/hm-nix-direnv.sh'
    nix_probe = 'nix_direnv_version 3.1.0\n' if nix_loader.exists() else ''
    # Both modes must enforce strict mode and the standard allow/deny gate.
    for index in range(2):
        project = root/f'project {index}'
        project.mkdir()
        (project/'.envrc').write_text(nix_probe + 'export NIXFILES_LAYOUT="$(direnv_layout_dir)"\nmkdir -p "$NIXFILES_LAYOUT"\n')
        assert run('direnv', 'exec', str(project), 'true', check=False).returncode != 0
        run('direnv', 'allow', str(project))
        loaded = run('direnv', 'exec', str(project), 'bash', '-c', 'printf "%s" "$NIXFILES_LAYOUT"').stdout
        digest = hashlib.sha1(str(project).encode()).hexdigest()
        assert loaded == str(root/'cache/direnv/layouts'/digest), loaded
        assert Path(loaded).is_dir() and not (project/'.direnv').exists()
    bad = root/'strict-mode'
    bad.mkdir()
    (bad/'.envrc').write_text('false\nexport NIXFILES_SHOULD_NOT_LOAD=yes\n')
    run('direnv', 'allow', str(bad))
    assert run('direnv', 'exec', str(bad), 'true', check=False).returncode != 0

    stdlib = config/'direnv/direnvrc'
    original_stdlib = stdlib.read_text()
    try:
        stdlib.write_text(original_stdlib + '\nnixfiles_live_probe() { printf live; }\n')
        project = root/'live-probe'
        project.mkdir()
        (project/'.envrc').write_text('export NIXFILES_LIVE="$(nixfiles_live_probe)"\n')
        run('direnv', 'allow', str(project))
        assert run('direnv', 'exec', str(project), 'bash', '-c', 'printf "%s" "$NIXFILES_LIVE"').stdout == 'live'
    finally:
        stdlib.write_text(original_stdlib)

    # Real PTYs exercise the plugin and bindings without opening external apps.
    browse = root/'browse'
    browse.mkdir()
    for name in ('dir2', 'dir10'):
        (browse/name).mkdir()
        (browse/name/f'inside-{name}.txt').write_text('fixture\n')
    (browse/'a-file.txt').write_text('fixture\n')
    (browse/'.hidden-probe').write_text('fixture\n')
    children = []
    transcript = (root/'yazi-transcript.txt').open('w')
    def start(directory, *extra):
        child = pexpect.spawn('yazi', [str(directory), *map(str, extra)], env=env,
                              dimensions=(35, 140), encoding='utf-8', timeout=15)
        child.logfile_read = transcript
        # pyte cannot parse private status probes such as Yazi's ?996n.
        # Ignore unsupported probes while retaining ordinary status handling.
        class Screen(pyte.Screen):
            def report_device_status(self, mode, private=False):
                if not private:
                    super().report_device_status(mode)
        child.screen = Screen(140, 35)
        child.stream = pyte.Stream(child.screen)
        children.append(child)
        return child
    def wait_for(child, text, *, absent=False):
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            try:
                data = child.read_nonblocking(65536, timeout=0.2)
            except pexpect.TIMEOUT:
                continue
            child.stream.feed(data)
            rendered = '\n'.join(child.screen.display)
            assert 'Theme load failed' not in rendered and 'Config load failed' not in rendered, rendered
            if '\x1b]11;?' in data:
                child.send('\x1b]11;rgb:1e1e/1e1e/2e2e\x07')
            if '\x1bP$q q' in data:
                child.send('\x1bP1$r2 q\x1b\\')
            if '\x1b[0c' in data:
                child.send('\x1b[?1;2c')
            if '\x1b[5n' in data:
                child.send('\x1b[0n')
            if (text in rendered) != absent:
                return
        raise AssertionError((text, child.screen.display))
    def quit_yazi(child):
        child.send('q')
        child.expect(pexpect.EOF)
        child.close()
        assert child.exitstatus == 0, child.exitstatus
    try:
        cwd_file = root/'cwd.txt'
        child = start(browse, '--cwd-file', cwd_file)
        wait_for(child, 'a-file.txt')
        child.send('H')
        wait_for(child, '.hidden-probe')
        child.send('?')
        wait_for(child, 'Enter the child directory, or open the file')
        child.send('\x03')
        wait_for(child, 'Enter the child directory, or open the file', absent=True)
        # Return to the first directory; hidden toggling preserves its hover.
        child.send('l')
        wait_for(child, str(browse/'dir2'))
        quit_yazi(child)
        assert cwd_file.read_text().strip() == str(browse/'dir2')

        opener = root/'open-file'
        opener.mkdir()
        opened_file = opener/'file one.txt'
        opened_file.write_text('fixture\n')
        chooser_file = root/'chosen.txt'
        child = start(opener, '--chooser-file', chooser_file)
        wait_for(child, 'file one.txt')
        child.send('l')
        child.expect(pexpect.EOF)
        child.close()
        assert chooser_file.read_text().strip() == str(opened_file)

        editor_log = root/'editor-args.txt'
        editor = root/'editor-probe'
        editor.write_text('#!/usr/bin/env bash\nprintf "%s\\n" "$@" > "$NIXFILES_EDITOR_LOG"\nprintf NIXFILES_EDITOR_DONE\n')
        editor.chmod(0o700)
        env.update(EDITOR=str(editor), NIXFILES_EDITOR_LOG=str(editor_log))
        child = start(opener)
        wait_for(child, 'file one.txt')
        child.send('e')
        child.expect('NIXFILES_EDITOR_DONE')
        child.screen.reset()
        wait_for(child, 'file one.txt')
        quit_yazi(child)
        assert editor_log.read_text().splitlines() == [str(opened_file)]

        settings = config/'yazi/yazi.toml'
        original = settings.read_text()
        try:
            settings.write_text(original.replace('show_hidden = false', 'show_hidden = true'))
            child = start(browse)
            wait_for(child, '.hidden-probe')
            quit_yazi(child)
        finally:
            settings.write_text(original)
    finally:
        for child in children:
            if child.isalive(): child.terminate(force=True)
        transcript.close()
    print('PASS: direnv authorization, strict mode, per-project cache, live stdlib; Yazi loading, natural sort, smart-enter, editor, hidden/help bindings, and live config.')
    PY

# Build Home Manager links and test the pinned Yazi/direnv runtime
test-yazi-direnv-nix:
    #!/usr/bin/env bash
    set -euo pipefail
    umask 077
    [[ "$NIXFILES_TEST_ROOT" == /* ]] || { printf 'NIXFILES_TEST_ROOT must be absolute.\n' >&2; exit 2; }
    mkdir -p "$NIXFILES_TEST_ROOT/cache"
    export XDG_CACHE_HOME="$NIXFILES_TEST_ROOT/cache"
    nix_cmd=(nix --extra-experimental-features 'nix-command flakes'
        --store "$NIXFILES_TEST_ROOT" --option build-users-group '')
    test_dir=$(mktemp -d "${TMPDIR:-/tmp}/nixfiles-yazi-direnv-nix.XXXXXX")
    test_home="$test_dir/home one"
    checkout="$test_dir/checkout one"
    anchor="$test_home/.local/share/nixfiles"
    mkdir -p "$checkout/src/dotfiles" "$test_home/.config/direnv/lib" "$test_home/.config/yazi"
    cp -R src/dotfiles/yazi src/dotfiles/direnv "$checkout/src/dotfiles/"
    just _copy-justfiles "$checkout"
    just --justfile "$checkout/justfile" link-checkout "$anchor"
    eval_args=(--impure --file src/tests/yazi-direnv.nix --argstr testHome "$test_home")
    "${nix_cmd[@]}" eval "${eval_args[@]}" --json metadata > "$test_dir/metadata.json"
    jq -e --arg anchor "$anchor" '
        .anchor == $anchor and (.configFiles | length) == 7 and
        .generated == {"settings":{},"keymap":{},"theme":{},"plugins":{},"direnvConfig":{},"direnvStdlib":""} and
        (.packages | index("yazi") != null) and (.packages | index("direnv") != null) and
        (.bashIntegration | contains("function yy()") and contains("hook bash")) and
        (.zshIntegration | contains("function yy()") and contains("hook zsh"))
    ' "$test_dir/metadata.json" > /dev/null
    files=$("${nix_cmd[@]}" build "${eval_args[@]}" --no-link --print-out-paths files)
    while IFS= read -r file; do
        source=$(readlink "$NIXFILES_TEST_ROOT$files/.config/$file")
        [[ "$(readlink "$NIXFILES_TEST_ROOT$source")" == "$anchor/src/dotfiles/$file" ]]
        mkdir -p "$(dirname "$test_home/.config/$file")"
        ln -s "$NIXFILES_TEST_ROOT$source" "$test_home/.config/$file"
    done < <(jq -r '.configFiles | keys[]' "$test_dir/metadata.json")
    nix_direnv_source=$(jq -r .nixDirenvSource "$test_dir/metadata.json")
    [[ "$(readlink "$NIXFILES_TEST_ROOT$files/.config/direnv/lib/hm-nix-direnv.sh")" == "$nix_direnv_source" ]]
    ln -s "$nix_direnv_source" "$test_home/.config/direnv/lib/hm-nix-direnv.sh"
    mv "$checkout" "$test_dir/checkout moved"
    just --justfile "$test_dir/checkout moved/justfile" link-checkout "$anchor"
    just --dry-run _test-yazi-direnv 2> "$test_dir/runtime.sh"
    export NIXFILES_CLI_CONFIG="$test_home/.config"
    export NIXFILES_CLI_TEST_DIR="$test_dir/runtime"
    "${nix_cmd[@]}" shell "${eval_args[@]}" runtime -c bash "$test_dir/runtime.sh"
    printf 'PASS: Home Manager links, nix-direnv loader, shell integration, relocation, and application runtime.\nReport: %s\n' "$test_dir"
