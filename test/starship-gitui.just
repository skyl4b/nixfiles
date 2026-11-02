# Check Starship/gitui adapters and native files without touching this home
test-starship-gitui:
    #!/usr/bin/env bash
    set -euo pipefail
    umask 077
    test_dir=$(mktemp -d "${TMPDIR:-/tmp}/nixfiles-starship-gitui.XXXXXX")
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
    [[ "$(readlink -f "$target/.config/starship.toml")" == "$checkout/src/dotfiles/starship/starship.toml" ]]
    for file in key_bindings.ron theme.ron LICENSE-catppuccin; do
        [[ "$(readlink -f "$target/.config/gitui/$file")" == "$checkout/src/dotfiles/gitui/$file" ]]
    done
    python - "$target/.config/starship.toml" <<'PY'
    import sys, tomllib
    from pathlib import Path
    config = tomllib.loads(Path(sys.argv[1]).read_text())
    assert config['palette'] in config['palettes']
    PY
    mv "$checkout" "$test_dir/checkout moved"
    checkout="$test_dir/checkout moved"
    chez apply
    chez verify
    [[ -f "$target/.config/starship.toml" && -f "$target/.config/gitui/theme.ron" ]]
    printf '\n# live edit probe\n' >> "$target/.config/starship.toml"
    [[ "$(tail -1 "$checkout/src/dotfiles/starship/starship.toml")" == '# live edit probe' ]]
    if grep -R -n '/nix/store/' "$checkout/src/dotfiles/starship" "$checkout/src/dotfiles/gitui"; then
        printf 'Portable prompt/Gitui config contains a store path.\n' >&2; exit 1
    fi
    printf 'PASS: Starship/gitui native links, TOML parsing, live edits, and relocation.\nReport: %s\n' "$test_dir"

# Render the real prompt and exercise gitui against a throwaway repository
_test-starship-gitui:
    #!/usr/bin/env bash
    set -euo pipefail
    python - <<'PY'
    import os, re, subprocess, time, tomllib
    from pathlib import Path
    import pexpect, pyte
    root = Path(os.environ['NIXFILES_PROMPT_TEST_DIR'])
    config = Path(os.environ['NIXFILES_PROMPT_CONFIG'])
    root.mkdir(parents=True)
    env = os.environ.copy()
    for name in ('NO_COLOR', 'GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR'):
        env.pop(name, None)
    env.update(XDG_CONFIG_HOME=str(config), XDG_CACHE_HOME=str(root/'cache'),
               XDG_DATA_HOME=str(root/'data'), XDG_STATE_HOME=str(root/'state'),
               STARSHIP_CONFIG=str(config/'starship.toml'), STARSHIP_CACHE=str(root/'starship-cache'),
               GIT_CONFIG_GLOBAL='/dev/null', GIT_CONFIG_NOSYSTEM='1',
               TERM='xterm-256color', COLORTERM='truecolor',
               AWS_PROFILE='nixfiles-fixture', AWS_VAULT='nixfiles-fixture', AWS_REGION='us-east-1',
               AWS_CONFIG_FILE=str(root/'aws-config'), AWS_SHARED_CREDENTIALS_FILE=str(root/'aws-credentials'),
               AWS_EC2_METADATA_DISABLED='true')
    (root/'aws-config').write_text('[profile nixfiles-fixture]\nregion = us-east-1\n')
    (root/'aws-credentials').write_text('[nixfiles-fixture]\naws_access_key_id = test-fixture\naws_secret_access_key = test-fixture\n')
    def run(*args, cwd=root):
        result = subprocess.run(args, cwd=cwd, env=env, text=True, capture_output=True)
        assert result.returncode == 0 and not result.stderr, (args, result.stdout, result.stderr)
        return result.stdout
    def plain(text):
        return re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', text)
    computed = tomllib.loads(run('starship', 'print-config', 'character', 'directory', 'palette'))
    assert computed['palette'] == 'catppuccin_mocha'
    assert computed['character']['success_symbol'] == '[λ](bold green)'
    assert computed['directory']['style'] == 'bold lavender'
    success = run('starship', 'module', 'character', '--status', '0')
    failure = run('starship', 'module', 'character', '--status', '1')
    assert plain(success).strip() == plain(failure).strip() == 'λ'
    assert '166;227;161' in success and '243;139;168' in failure
    assert '(us-east-1)' in plain(run('starship', 'module', 'aws'))
    directory = run('starship', 'module', 'directory', '--path', str(root))
    assert '180;190;254' in directory
    repo = root/'repository'
    repo.mkdir()
    def git(*args):
        return run('git', '-C', str(repo), *args)
    git('init', '-q', '--template=', '--initial-branch=nixfiles-fixture')
    for name in ('alpha','beta'):
        (repo/f'{name}.txt').write_text('base\n')
    git('add', '.')
    git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
        '-c', 'commit.gpgsign=false', 'commit', '-qm', 'Fixture')
    assert 'nixfiles-fixture' in plain(run('starship', 'module', 'git_branch', '--path', str(repo)))
    git('checkout', '--detach', '-q', 'HEAD')
    assert not run('starship', 'module', 'git_branch', '--path', str(repo))
    git('checkout', '-q', 'nixfiles-fixture')
    settings = config/'starship.toml'
    original = settings.read_text()
    try:
        settings.write_text(original.replace('[λ](bold green)', '[LIVE](bold green)'))
        assert plain(run('starship', 'module', 'character')).strip() == 'LIVE'
    finally:
        settings.write_text(original)
    for name in ('alpha','beta'):
        (repo/f'{name}.txt').write_text(f'{name.upper()}_PROBE\n')
    children = []
    transcript = (root/'gitui-transcript.txt').open('w')
    def start():
        child = pexpect.spawn('gitui', ['--logging'], cwd=repo, env=env,
                              dimensions=(40,140), encoding='utf-8', timeout=10)
        child.logfile_read = transcript
        child.screen = pyte.Screen(140,40)
        child.stream = pyte.Stream(child.screen)
        children.append(child)
        return child
    def wait_for(child, predicate):
        deadline = time.monotonic()+10
        while time.monotonic()<deadline:
            try: child.stream.feed(child.read_nonblocking(65536, timeout=0.2))
            except pexpect.TIMEOUT: continue
            if predicate('\n'.join(child.screen.display)): return
        raise AssertionError(child.screen.display)
    def colors(child):
        return {value for row in child.screen.buffer.values() for cell in row.values()
                for value in (cell.fg, cell.bg)}
    def quit_gitui(child):
        child.send('q')
        child.expect(pexpect.EOF)
        child.close()
        assert child.exitstatus == 0
    try:
        child = start()
        wait_for(child, lambda screen: 'ALPHA_PROBE' in screen)
        assert 'cdd6f4' in colors(child), colors(child)
        child.send('j')
        wait_for(child, lambda screen: 'BETA_PROBE' in screen)
        child.send('k')
        wait_for(child, lambda screen: 'ALPHA_PROBE' in screen)
        child.send('\x1bOP')
        wait_for(child, lambda screen: 'Help: all commands' in screen)
        child.send('\x1b')
        wait_for(child, lambda screen: 'Help: all commands' not in screen and 'ALPHA_PROBE' in screen)
        quit_gitui(child)
        theme = config/'gitui/theme.ron'
        original_theme = theme.read_text()
        try:
            theme.write_text(original_theme.replace('#cdd6f4', '#112233'))
            child = start()
            wait_for(child, lambda screen: 'ALPHA_PROBE' in screen)
            assert '112233' in colors(child), colors(child)
            quit_gitui(child)
        finally:
            theme.write_text(original_theme)
    finally:
        for child in children:
            if child.isalive(): child.terminate(force=True)
        transcript.close()
    log = root/'cache/gitui/gitui.log'
    assert log.exists() and '[ERROR]' not in log.read_text()
    print('PASS: Starship loading, colors, literal formats, branch/detached behavior, live prompt edits; gitui RON loading, theme colors, j/k navigation, F1 help, and live theme edits.')
    PY

# Build Home Manager links and test pinned Starship/gitui without activation
test-starship-gitui-nix:
    #!/usr/bin/env bash
    set -euo pipefail
    umask 077
    [[ "$NIXFILES_TEST_ROOT" == /* ]] || { printf 'NIXFILES_TEST_ROOT must be absolute.\n' >&2; exit 2; }
    mkdir -p "$NIXFILES_TEST_ROOT/cache"
    export XDG_CACHE_HOME="$NIXFILES_TEST_ROOT/cache"
    nix_cmd=(nix --extra-experimental-features 'nix-command flakes'
        --store "$NIXFILES_TEST_ROOT" --option build-users-group '')
    test_dir=$(mktemp -d "${TMPDIR:-/tmp}/nixfiles-starship-gitui-nix.XXXXXX")
    test_home="$test_dir/home"
    checkout="$test_dir/checkout one"
    anchor="$test_home/.local/share/nixfiles"
    mkdir -p "$checkout/src/dotfiles" "$test_home/.config/gitui"
    cp -R src/dotfiles/starship src/dotfiles/gitui "$checkout/src/dotfiles/"
    just _copy-justfiles "$checkout"
    just --justfile "$checkout/justfile" link-checkout "$anchor"
    eval_args=(--impure --file src/tests/starship-gitui.nix --argstr testHome "$test_home")
    "${nix_cmd[@]}" eval "${eval_args[@]}" --json metadata > "$test_dir/metadata.json"
    jq -e --arg anchor "$anchor" --arg config "$test_home/.config/starship.toml" '
        .anchor == $anchor and (.configFiles | length) == 4 and
        .starshipSettings == {} and .starshipConfig == $config and .gituiEnabled == false and
        (.packages | index("starship") != null) and (.packages | index("gitui") != null) and
        (.bashIntegration | contains("init bash")) and (.zshIntegration | contains("init zsh"))
    ' "$test_dir/metadata.json" > /dev/null
    files=$("${nix_cmd[@]}" build "${eval_args[@]}" --no-link --print-out-paths files)
    while IFS=$'\t' read -r file native; do
        source=$(readlink "$NIXFILES_TEST_ROOT$files/.config/$file")
        [[ "$(readlink "$NIXFILES_TEST_ROOT$source")" == "$anchor/src/dotfiles/$native" ]]
        ln -s "$NIXFILES_TEST_ROOT$source" "$test_home/.config/$file"
    done < <(jq -r '.configFiles | to_entries[] | [.key,.value] | @tsv' "$test_dir/metadata.json")
    mv "$checkout" "$test_dir/checkout moved"
    just --justfile "$test_dir/checkout moved/justfile" link-checkout "$anchor"
    just --dry-run _test-starship-gitui 2> "$test_dir/runtime.sh"
    export NIXFILES_PROMPT_CONFIG="$test_home/.config"
    export NIXFILES_PROMPT_TEST_DIR="$test_dir/runtime"
    "${nix_cmd[@]}" shell "${eval_args[@]}" runtime -c bash "$test_dir/runtime.sh"
    printf 'PASS: Home Manager links, shell hooks, relocation, and pinned application runtime.\nReport: %s\n' "$test_dir"
