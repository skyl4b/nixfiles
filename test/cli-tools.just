# Check shared CLI files and chezmoi links in a temporary home
test-cli-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    umask 077
    test_dir=$(mktemp -d "${TMPDIR:-/tmp}/nixfiles-cli-tools.XXXXXX")
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
    for file in bat/config bat/themes bat/LICENSE-catppuccin bottom/bottom.toml bottom/LICENSE-catppuccin ripgrep/ripgreprc tealdeer/config.toml commitlint/commitlint.config.js; do
        [[ "$(readlink -f "$target/.config/$file")" == "$checkout/src/dotfiles/$file" ]]
    done
    python - "$target/.config" <<'PY'
    import plistlib, sys, tomllib
    from pathlib import Path
    config = Path(sys.argv[1])
    for file in ('bottom/bottom.toml', 'tealdeer/config.toml'):
        tomllib.loads((config / file).read_text())
    with (config / 'bat/themes/Catppuccin Mocha.tmTheme').open('rb') as theme:
        plistlib.load(theme)
    PY
    printf '\n--fixed-strings\n' >> "$target/.config/ripgrep/ripgreprc"
    [[ "$(tail -1 "$checkout/src/dotfiles/ripgrep/ripgreprc")" == --fixed-strings ]]
    mv "$checkout" "$test_dir/checkout moved"
    checkout="$test_dir/checkout moved"
    chez apply
    chez verify
    [[ -f "$target/.config/bat/themes/Catppuccin Mocha.tmTheme" ]]
    if grep -R -n '/nix/store/' "$checkout/src/dotfiles/"{bat,bottom,ripgrep,tealdeer}; then
        printf 'Portable CLI config contains a store path.\n' >&2; exit 1
    fi
    printf 'PASS: CLI config/theme links, syntax, live edits, and relocation.\nReport: %s\n' "$test_dir"

# Build isolated Home Manager links, then load them with pinned applications
test-cli-tools-nix:
    #!/usr/bin/env bash
    set -euo pipefail
    umask 077
    [[ "$NIXFILES_TEST_ROOT" == /* ]] || { printf 'NIXFILES_TEST_ROOT must be absolute.\n' >&2; exit 2; }
    mkdir -p "$NIXFILES_TEST_ROOT/cache"
    export XDG_CACHE_HOME="$NIXFILES_TEST_ROOT/cache"
    nix_cmd=(nix --extra-experimental-features 'nix-command flakes'
        --store "$NIXFILES_TEST_ROOT" --option build-users-group '')
    test_dir=$(mktemp -d "${TMPDIR:-/tmp}/nixfiles-cli-tools-nix.XXXXXX")
    test_home="$test_dir/home one"
    checkout="$test_dir/checkout one"
    anchor="$test_home/.local/share/nixfiles"
    mkdir -p "$checkout/src/dotfiles" "$test_home/.config"
    cp -R src/dotfiles/{bat,bottom,ripgrep,tealdeer} "$checkout/src/dotfiles/"
    just _copy-justfiles "$checkout"
    just --justfile "$checkout/justfile" link-checkout "$anchor"
    eval_args=(--impure --file src/tests/cli-tools.nix --argstr testHome "$test_home")
    "${nix_cmd[@]}" eval "${eval_args[@]}" --json metadata > "$test_dir/metadata.json"
    jq -e --arg anchor "$anchor" --arg config "$test_home/.config/ripgrep/ripgreprc" '
        .anchor == $anchor and (.configFiles | length) == 7 and .ripgrepConfig == $config and
        (.batCache | contains("cache --build")) and .updateTimer.Timer.OnCalendar == "weekly" and
        (["bat","bottom","ripgrep","tealdeer","batdiff","batman","batgrep","batwatch"] - .packages | length) == 0
    ' "$test_dir/metadata.json" > /dev/null
    files=$("${nix_cmd[@]}" build "${eval_args[@]}" --no-link --print-out-paths files)
    while IFS= read -r file; do
        source=$(readlink "$NIXFILES_TEST_ROOT$files/.config/$file")
        [[ "$(readlink "$NIXFILES_TEST_ROOT$source")" == "$anchor/src/dotfiles/$file" ]]
        mkdir -p "$(dirname "$test_home/.config/$file")"
        ln -s "$NIXFILES_TEST_ROOT$source" "$test_home/.config/$file"
    done < <(jq -r '.configFiles | keys[]' "$test_dir/metadata.json")
    mv "$checkout" "$test_dir/checkout moved"
    just --justfile "$test_dir/checkout moved/justfile" link-checkout "$anchor"
    just --dry-run _test-cli-tools 2> "$test_dir/runtime.sh"
    export NIXFILES_TOOLS_CONFIG="$test_home/.config"
    export NIXFILES_TOOLS_TEST_DIR="$test_dir/runtime"
    "${nix_cmd[@]}" shell "${eval_args[@]}" runtime -c bash "$test_dir/runtime.sh"
    printf 'PASS: Home Manager links, bat cache hook, tealdeer timer, relocation, and pinned CLI runtime.\nReport: %s\n' "$test_dir"

# Exercise config loading and live edits without a real home or network updates
_test-cli-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "$NIXFILES_TOOLS_TEST_DIR"
    export XDG_CONFIG_HOME="$NIXFILES_TOOLS_CONFIG"
    export XDG_CACHE_HOME="$NIXFILES_TOOLS_TEST_DIR/cache"
    export BAT_CONFIG_PATH="$XDG_CONFIG_HOME/bat/config"
    export BAT_CACHE_PATH="$XDG_CACHE_HOME/bat"
    export RIPGREP_CONFIG_PATH="$XDG_CONFIG_HOME/ripgrep/ripgreprc"
    export COLORTERM=truecolor
    unset BAT_THEME BAT_OPTS NO_COLOR
    bat cache --build > "$NIXFILES_TOOLS_TEST_DIR/bat-cache.log" 2>&1
    python - <<'PY'
    import os, subprocess, time
    from pathlib import Path
    import pexpect, pyte
    config = Path(os.environ['XDG_CONFIG_HOME'])
    work = Path(os.environ['NIXFILES_TOOLS_TEST_DIR'])
    def run(*args):
        return subprocess.run(args, check=True, capture_output=True).stdout
    sample = work / 'sample.rs'
    sample.write_text('fn main() { println!("nixfiles"); }\n')
    themes = run('bat', '--list-themes', '--color=never')
    assert b'Catppuccin Mocha' in themes
    bat_args = ('bat', '--color=always', '--paging=never', '--style=plain', str(sample))
    colored = run(*bat_args)
    (work / 'bat-output.txt').write_bytes(colored)
    assert b'\x1b[38;2;' in colored and b'nixfiles' in colored
    (config / 'bat/config').write_text('--theme=ansi\n')
    assert run(*bat_args) != colored, 'bat did not load the live config edit'
    search = work / 'search.txt'
    search.write_text('alpha\nALPHA\nAlpha\n')
    assert run('rg', 'alpha', str(search)).decode().splitlines() == ['alpha', 'ALPHA', 'Alpha']
    assert run('rg', 'Alpha', str(search)).decode().splitlines() == ['Alpha']
    assert run('rg', '--case-sensitive', 'alpha', str(search)).decode().splitlines() == ['alpha']
    with (config / 'ripgrep/ripgreprc').open('a') as rc:
        rc.write('--fixed-strings\n')
    assert subprocess.run(['rg', 'al.ha', str(search)], capture_output=True).returncode == 1
    page = work / 'probe.md'
    page.write_text('# nixfiles-probe\n\n> Native config probe.\n\n- Example text:\n\n`printf ' + '{' * 2 + 'hello' + '}' * 2 + '`\n')
    tldr_args = ('tldr', '--config-path', str(config / 'tealdeer/config.toml'), '--no-auto-update', '--color', 'always', '--render', str(page))
    rendered = run(*tldr_args)
    assert b'Example text' in rendered and b'hello' in rendered
    assert b'\x1b[32m' in rendered, 'tealdeer did not apply the example text color'
    tldr_config = config / 'tealdeer/config.toml'
    tldr_config.write_text(tldr_config.read_text().replace('foreground = "green"', 'foreground = "magenta"'))
    assert b'\x1b[35m' in run(*tldr_args), 'tealdeer did not load the live config edit'
    def bottom(expected_color):
        screen = pyte.Screen(120, 40)
        stream = pyte.Stream(screen)
        child = pexpect.spawn('btm', ['--config_location', str(config / 'bottom/bottom.toml'), '--basic', '--disable_gpu'],
                              env={**os.environ, 'TERM': 'xterm-256color'}, dimensions=(40, 120), encoding='utf-8', timeout=8)
        output = []
        try:
            deadline = time.monotonic() + 8
            while time.monotonic() < deadline:
                try:
                    chunk = child.read_nonblocking(65536, timeout=0.2)
                except pexpect.TIMEOUT:
                    continue
                output.append(chunk)
                stream.feed(chunk)
                colors = {cell.fg for row in screen.buffer.values() for cell in row.values()}
                if expected_color in colors and 'PID' in '\n'.join(screen.display):
                    break
            else:
                raise AssertionError('bottom did not render its native theme')
            child.send('q')
            child.expect(pexpect.EOF)
            child.close()
            assert child.exitstatus == 0
        finally:
            child.close(force=True)
            (work / f'bottom-{expected_color}.log').write_text(''.join(output))
    bottom('cdd6f4')
    bottom_config = config / 'bottom/bottom.toml'
    bottom_config.write_text(bottom_config.read_text().replace('#cdd6f4', '#123abc'))
    bottom('123abc')
    print('PASS: bat cache/theme, ripgrep smart case, tealdeer offline rendering, bottom theme, and live edits.')
    PY
