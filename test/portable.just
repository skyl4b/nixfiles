# Rehearse the complete chezmoi deployment and pinned applications in one temporary home
test-portable-nix:
    #!/usr/bin/env bash
    set -euo pipefail
    umask 077
    test_dir=$(mktemp -d "${TMPDIR:-/tmp}/nixfiles-portable.XXXXXX")
    checkout="$test_dir/checkout one"
    target="$test_dir/home one"
    mkdir -p "$checkout/src" "$target"
    cp -R src/dotfiles src/chezmoi "$checkout/src/"
    just _copy-justfiles "$checkout"
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git init -q --template= "$checkout"
    eval_args=(--impure --file src/tests/portable.nix --argstr testHome "$target")
    just _nix eval "${eval_args[@]}" --json metadata >"$test_dir/metadata.json"
    run() { just --justfile "$checkout/justfile" "$@"; }
    run dotfiles-diff "$target" >"$test_dir/before.diff"
    [[ -s "$test_dir/before.diff" && ! -e "$target/.config" ]]
    run dotfiles-apply "$target"
    run dotfiles-diff "$target" >"$test_dir/after.diff"
    [[ ! -s "$test_dir/after.diff" ]]
    verify_links() {
        python - "$test_dir/metadata.json" "$target" "$checkout" <<'PY'
    import json, sys
    from pathlib import Path
    expected = json.loads(Path(sys.argv[1]).read_text())['configFiles']
    config = Path(sys.argv[2])/'.config'
    checkout = Path(sys.argv[3])
    links = {str(p.relative_to(config)): p for p in config.rglob('*') if p.is_symlink()}
    assert set(links) == set(expected), (sorted(links), sorted(expected))
    for name, source in expected.items():
        assert links[name].resolve(strict=True) == checkout/'src/dotfiles'/source, name
    assert not (config/'direnv/lib/hm-nix-direnv.sh').exists()
    assert not (config/'tmux/plugins').exists()
    for file in (checkout/'src/dotfiles').rglob('*'):
        if file.is_file():
            data = file.read_bytes()
            assert b'/nix/store/' not in data and b'/home/skylab/' not in data, str(file)
    print(f'PASS: all {len(links)} native targets match Home Manager ownership, with no Nix-only links.')
    PY
    }
    verify_links >"$test_dir/links-before.log"
    mv "$checkout" "$test_dir/checkout moved"
    checkout="$test_dir/checkout moved"
    run dotfiles-apply "$target"
    run dotfiles-diff "$target" >"$test_dir/relocated.diff"
    [[ ! -s "$test_dir/relocated.diff" ]]
    verify_links >"$test_dir/links-after.log"
    for recipe in _test-tmux _test-yazi-direnv _test-starship-gitui _test-cli-tools _test-desktop-tools _test-portable; do
        just --dry-run "$recipe" 2>"$test_dir/$recipe.sh"
    done
    export NIXFILES_PORTABLE_TEST_DIR="$test_dir"
    export NIXFILES_PORTABLE_CONFIG="$target/.config"
    export NIXFILES_DESKTOP_FONTS
    NIXFILES_DESKTOP_FONTS=$(jq -r .fonts "$test_dir/metadata.json")
    just _nix shell "${eval_args[@]}" runtime -c bash "$test_dir/_test-portable.sh"
    run dotfiles-diff "$target" >"$test_dir/final.diff"
    [[ ! -s "$test_dir/final.diff" ]]
    verify_links >"$test_dir/links-final.log"
    printf 'PASS: complete portable deployment, relocation, and application rehearsal.\nReport: %s\n' "$test_dir/summary.md"

# Application checks share chezmoi's home and keep separate runtime state
_test-portable:
    #!/usr/bin/env bash
    set -euo pipefail
    test_dir="$NIXFILES_PORTABLE_TEST_DIR"
    config="$NIXFILES_PORTABLE_CONFIG"
    summary="$test_dir/summary.md"
    failures=0
    export XDG_CONFIG_HOME="$config" XDG_CACHE_HOME="$test_dir/cache"
    export XDG_DATA_HOME="$test_dir/data" XDG_STATE_HOME="$test_dir/state"
    export SHELL
    SHELL=$(command -v bash)
    mkdir -p "$test_dir/tmux" "$test_dir/work" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"
    cd "$test_dir/work"
    {
        printf '# Portable deployment rehearsal\n\n'
        printf 'Captured: %s\n\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
        if [[ -f /etc/os-release ]]; then
            cat /etc/os-release >"$test_dir/os-release"
            printf 'Host OS: see os-release. Applications use the pinned test store.\n\n'
        fi
        cat "$test_dir/links-after.log"
        printf '\n| Application group | Result |\n| --- | --- |\n'
    } >"$summary"
    run_check() {
        local name=$1
        shift
        if "$@" >"$test_dir/$name.log" 2>&1; then
            printf '| %s | PASS |\n' "$name" >>"$summary"
        else
            printf '| %s | FAIL: see %s.log |\n' "$name" "$name" >>"$summary"
            failures=$((failures + 1))
        fi
    }
    check_commitlint() {
        local args=(commitlint --config "$config/commitlint/commitlint.config.js" --strict)
        printf 'feat: portable config probe\n' | "${args[@]}" || return
        if printf 'invalid commit message\n' | "${args[@]}"; then
            printf 'Commitlint accepted the invalid fixture.\n' >&2
            return 1
        fi
    }
    run_check git env GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$config/git/config" \
        git config --global --includes --list --show-origin
    run_check commitlint check_commitlint
    run_check tmux env NIXFILES_TERMINAL_CONFIG="$config" NIXFILES_TERMINAL_TEST_DIR="$test_dir/tmux" \
        NIXFILES_TERMINAL_PLUGINS=0 bash "$test_dir/_test-tmux.sh"
    run_check ghostty ghostty +validate-config --config-file="$config/ghostty/config"
    run_check yazi-direnv env NIXFILES_CLI_CONFIG="$config" NIXFILES_CLI_TEST_DIR="$test_dir/yazi-direnv" \
        bash "$test_dir/_test-yazi-direnv.sh"
    run_check starship-gitui env NIXFILES_PROMPT_CONFIG="$config" NIXFILES_PROMPT_TEST_DIR="$test_dir/starship-gitui" \
        bash "$test_dir/_test-starship-gitui.sh"
    run_check cli-tools env NIXFILES_TOOLS_CONFIG="$config" NIXFILES_TOOLS_TEST_DIR="$test_dir/cli-tools" \
        bash "$test_dir/_test-cli-tools.sh"
    run_check desktop-tools env NIXFILES_DESKTOP_CONFIG="$config" NIXFILES_DESKTOP_TEST_DIR="$test_dir/desktop-tools" \
        bash "$test_dir/_test-desktop-tools.sh"
    printf '\n%s failing application groups.\n' "$failures" >>"$summary"
    cat "$summary"
    (( failures == 0 ))
