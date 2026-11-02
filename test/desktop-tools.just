# Verify shared Zellij, Hyfetch, and Zathura files through chezmoi
test-desktop-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    umask 077
    test_dir=$(mktemp -d "${TMPDIR:-/tmp}/nixfiles-desktop-tools.XXXXXX")
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
    [[ "$(readlink -f "$target/.config/hyfetch.json")" == "$checkout/src/dotfiles/hyfetch/hyfetch.json" ]]
    for file in zellij/config.kdl zathura/zathurarc; do
        [[ "$(readlink -f "$target/.config/$file")" == "$checkout/src/dotfiles/$file" ]]
    done
    jq -e . "$target/.config/hyfetch.json" > /dev/null
    printf '\n// live edit probe\n' >> "$target/.config/zellij/config.kdl"
    [[ "$(tail -1 "$checkout/src/dotfiles/zellij/config.kdl")" == '// live edit probe' ]]
    mv "$checkout" "$test_dir/checkout moved"
    checkout="$test_dir/checkout moved"
    chez apply
    chez verify
    [[ -f "$target/.config/zathura/zathurarc" && -f "$target/.config/hyfetch.json" ]]
    if grep -R -n '/nix/store/' "$checkout/src/dotfiles/"{zellij,hyfetch,zathura}; then
        printf 'Portable desktop config contains a store path.\n' >&2; exit 1
    fi
    printf 'PASS: Zellij/Hyfetch/Zathura links, JSON parsing, live edits, and relocation.\nReport: %s\n' "$test_dir"

# Build an isolated home and test the pinned terminal and PDF applications
test-desktop-tools-nix:
    #!/usr/bin/env bash
    set -euo pipefail
    umask 077
    [[ "$NIXFILES_TEST_ROOT" == /* ]] || { printf 'NIXFILES_TEST_ROOT must be absolute.\n' >&2; exit 2; }
    mkdir -p "$NIXFILES_TEST_ROOT/cache"
    export XDG_CACHE_HOME="$NIXFILES_TEST_ROOT/cache"
    nix_cmd=(nix --extra-experimental-features 'nix-command flakes'
        --store "$NIXFILES_TEST_ROOT" --option build-users-group '')
    test_dir=$(mktemp -d "${TMPDIR:-/tmp}/nixfiles-desktop-tools-nix.XXXXXX")
    test_home="$test_dir/home one"
    checkout="$test_dir/checkout one"
    anchor="$test_home/.local/share/nixfiles"
    mkdir -p "$checkout/src/dotfiles" "$test_home/.config"
    cp -R src/dotfiles/{zellij,hyfetch,zathura} "$checkout/src/dotfiles/"
    just _copy-justfiles "$checkout"
    just --justfile "$checkout/justfile" link-checkout "$anchor"
    eval_args=(--impure --file src/tests/desktop-tools.nix --argstr testHome "$test_home")
    "${nix_cmd[@]}" eval "${eval_args[@]}" --json metadata > "$test_dir/metadata.json"
    jq -e --arg anchor "$anchor" '
        .anchor == $anchor and (.configFiles | length) == 3 and
        (.bashIntegration | contains("setup --generate-auto-start bash")) and
        .sessionVariables.ZELLIJ_AUTO_ATTACH == "false" and .sessionVariables.ZELLIJ_AUTO_EXIT == "false" and
        (["zellij","hyfetch","zathura-with-plugins"] - .packages | length) == 0
    ' "$test_dir/metadata.json" > /dev/null
    files=$("${nix_cmd[@]}" build "${eval_args[@]}" --no-link --print-out-paths files)
    while IFS=$'\t' read -r file native; do
        source=$(readlink "$NIXFILES_TEST_ROOT$files/.config/$file")
        [[ "$(readlink "$NIXFILES_TEST_ROOT$source")" == "$anchor/src/dotfiles/$native" ]]
        mkdir -p "$(dirname "$test_home/.config/$file")"
        ln -s "$NIXFILES_TEST_ROOT$source" "$test_home/.config/$file"
    done < <(jq -r '.configFiles | to_entries[] | [.key,.value] | @tsv' "$test_dir/metadata.json")
    mv "$checkout" "$test_dir/checkout moved"
    just --justfile "$test_dir/checkout moved/justfile" link-checkout "$anchor"
    just --dry-run _test-desktop-tools 2> "$test_dir/runtime.sh"
    export NIXFILES_DESKTOP_CONFIG="$test_home/.config"
    export NIXFILES_DESKTOP_TEST_DIR="$test_dir/runtime"
    export NIXFILES_DESKTOP_FONTS
    NIXFILES_DESKTOP_FONTS=$(jq -r .fonts "$test_dir/metadata.json")
    "${nix_cmd[@]}" shell "${eval_args[@]}" runtime -c bash "$test_dir/runtime.sh"
    printf 'PASS: Home Manager links, Bash integration, relocation, and pinned Zellij/Hyfetch/Zathura runtime.\nReport: %s\n' "$test_dir"

# Keep terminal sessions, display, application state, and test documents private
_test-desktop-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    python - <<'PY'
    import json, os, re, select, shutil, subprocess, time
    from pathlib import Path
    from xml.sax.saxutils import escape
    import pexpect
    root = Path(os.environ['NIXFILES_DESKTOP_TEST_DIR'])
    config = Path(os.environ['NIXFILES_DESKTOP_CONFIG'])
    root.mkdir(parents=True)
    env = os.environ.copy()
    for name in ('ZELLIJ', 'ZELLIJ_SESSION_NAME', 'ZELLIJ_PANE_ID', 'DISPLAY', 'WAYLAND_DISPLAY', 'DBUS_SESSION_BUS_ADDRESS'):
        env.pop(name, None)
    env.update(XDG_CONFIG_HOME=str(config), XDG_CACHE_HOME=str(root/'cache'),
               XDG_DATA_HOME=str(root/'data'), XDG_STATE_HOME=str(root/'state'), XDG_RUNTIME_DIR=str(root/'run'),
               ZELLIJ_SOCKET_DIR=str(root/'ipc'), TERM='xterm-256color', COLORTERM='truecolor',
               SHELL=shutil.which('bash'), BASH_ENV='/dev/null', ENV='/dev/null', PS1='NIXFILES_PROMPT> ')
    (root/'run').mkdir(mode=0o700)
    def run(*args):
        result = subprocess.run(args, env=env, cwd=root, text=True, capture_output=True, timeout=15)
        assert result.returncode == 0, (args, result.stdout, result.stderr)
        return result.stdout
    check = run('zellij', '--config', str(config/'zellij/config.kdl'), 'setup', '--check')
    (root/'zellij-check.txt').write_text(check)
    assert 'well defined' in check.lower(), check
    layout = root/'layout.kdl'
    layout.write_text('layout { pane command=' + json.dumps(shutil.which('bash')) + ' { args "--noprofile" "--norc"; }; }\n')
    transcript = (root/'zellij-terminal.txt').open('w')
    child = pexpect.spawn('zellij', ['--config', str(config/'zellij/config.kdl'), '--layout', str(layout),
                                  'options', '--session-name', 'nixfiles-test', '--web-server', 'false', '--session-serialization', 'false'],
                          cwd=root, env=env, dimensions=(30,120), encoding='utf-8', timeout=15)
    child.logfile_read = transcript
    try:
        child.expect('NIXFILES_PROMPT>')
        child.send('\x11')
        time.sleep(0.3)
        assert child.isalive(), 'Zellij did not start locked'
        child.send('\x00')
        child.send('\x11')
        child.expect(pexpect.EOF)
        child.close()
        assert child.exitstatus == 0
    finally:
        subprocess.run(['zellij', 'kill-session', 'nixfiles-test'], env=env, capture_output=True, timeout=10)
        child.close(force=True)
        transcript.close()
    art = root/'ascii.txt'
    art.write_text('NIXFILES_LOGO\n' * 6)
    def hyfetch():
        child = pexpect.spawn('hyfetch', ['-C', str(config/'hyfetch.json'), '--ascii-file', str(art),
                              '--auto-detect-light-dark=false', '--args=--config none --disable packages gpu disk local_ip public_ip'],
                              env=env, cwd=root, dimensions=(40,120), encoding='utf-8', timeout=20)
        try:
            child.expect(pexpect.EOF)
            output = child.before
            child.close()
            assert child.exitstatus == 0 and 'NIXFILES_LOGO' in output, output
            return output
        finally:
            child.close(force=True)
    rainbow = hyfetch()
    (root/'hyfetch-rainbow.txt').write_text(rainbow)
    settings = config/'hyfetch.json'
    changed = json.loads(settings.read_text())
    changed['preset'] = 'transgender'
    settings.write_text(json.dumps(changed))
    other = hyfetch()
    colors = lambda text: set(re.findall(r'\x1b\[38;2;(\d+;\d+;\d+)m', text))
    assert colors(rainbow) and colors(other) and colors(rainbow) != colors(other), 'Hyfetch did not load the live preset edit'
    # Minimal two-page PDF used only to exercise the viewer's native bindings.
    objects = [b'<< /Type /Catalog /Pages 2 0 R >>', b'<< /Type /Pages /Kids [3 0 R 5 0 R] /Count 2 >>',
               b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 400] /Contents 4 0 R >>', b'<< /Length 0 >>\nstream\n\nendstream',
               b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 400] /Contents 6 0 R >>', b'<< /Length 0 >>\nstream\n\nendstream']
    document = bytearray(b'%PDF-1.4\n')
    offsets = [0]
    for index, obj in enumerate(objects, 1):
        offsets.append(len(document))
        document.extend(f'{index} 0 obj\n'.encode() + obj + b'\nendobj\n')
    xref = len(document)
    document.extend(f'xref\n0 {len(offsets)}\n0000000000 65535 f \n'.encode())
    for offset in offsets[1:]:
        document.extend(f'{offset:010d} 00000 n \n'.encode())
    document.extend(f'trailer\n<< /Size {len(offsets)} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n'.encode())
    pdf = root/'nixfiles-probe.pdf'
    pdf.write_bytes(document)
    fontconfig = root/'fonts.conf'
    fontconfig.write_text('<fontconfig><dir>' + escape(os.environ['NIXFILES_DESKTOP_FONTS']) + '</dir><cachedir>' + escape(str(root/'font-cache')) + '</cachedir></fontconfig>')
    env.update(FONTCONFIG_FILE=str(fontconfig), GDK_BACKEND='x11', GTK_USE_PORTAL='0')
    config_file = config/'zathura/zathurarc'
    config_file.write_text(config_file.read_text() + '\nset window-title-page true\n')
    display_read, display_write = os.pipe()
    xvfb_log = (root/'xvfb.log').open('w')
    server = subprocess.Popen(['Xvfb', '-displayfd', str(display_write), '-screen', '0', '1024x768x24', '-nolisten', 'tcp'],
                               pass_fds=(display_write,), env=env, stdout=xvfb_log, stderr=xvfb_log)
    os.close(display_write)
    try:
        assert select.select([display_read], [], [], 10)[0], 'Virtual display did not start'
        display = os.read(display_read, 32).decode().strip()
        assert display.isdigit(), display
        env['DISPLAY'] = ':' + display
        def viewer(start_page, keys):
            log = (root/f'zathura-{start_page}.log').open('w')
            bus_config = Path(shutil.which('dbus-run-session')).resolve().parent.parent/'share/dbus-1/session.conf'
            app = subprocess.Popen(['dbus-run-session', '--config-file', str(bus_config), '--', 'zathura', '--config-dir', str(config/'zathura'),
                                    '--data-dir', str(root/'zathura-data'), '--cache-dir', str(root/'zathura-cache'),
                                    '--log-level', 'debug', '--page', str(start_page), str(pdf)], env=env, stdout=log, stderr=log)
            def wait_for(page):
                deadline = time.monotonic() + 10
                while time.monotonic() < deadline:
                    assert app.poll() is None, 'Zathura exited; see its test log'
                    windows = subprocess.run(['xdotool', 'search', '--onlyvisible', '--name', 'nixfiles-probe'], env=env, capture_output=True, text=True).stdout.splitlines()
                    for window in windows:
                        title = run('xdotool', 'getwindowname', window)
                        if re.search(r'\[' + str(page) + r'/2\]', title):
                            return window
                    time.sleep(0.1)
                raise AssertionError(f'Zathura did not display page {page}')
            try:
                window = wait_for(start_page)
                run('xdotool', 'windowfocus', '--sync', window)
                for key, page in keys:
                    run('xdotool', 'key', '--clearmodifiers', key)
                    wait_for(page)
                run('xdotool', 'key', '--clearmodifiers', 'q')
                assert app.wait(timeout=10) == 0
            finally:
                if app.poll() is None:
                    app.terminate()
                    app.wait(timeout=10)
                log.close()
        viewer(1, [('ctrl+d', 2), ('ctrl+u', 1)])
        config_file.write_text(config_file.read_text().replace('map <C-d>   navigate next', 'map <C-d>   navigate previous'))
        viewer(2, [('ctrl+d', 1)])
    finally:
        server.terminate()
        server.wait(timeout=10)
        os.close(display_read)
        xvfb_log.close()
    print('PASS: Zellij config and Ctrl-Space unlock, Hyfetch presets, Zathura page bindings, and live edits.')
    PY
