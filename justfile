#!/usr/bin/env -S just --justfile

set tempdir := "/tmp"

# Keep test state under Pixi unless a writable scratch root is supplied.
export NIXFILES_TEST_ROOT := env("NIXFILES_TEST_ROOT", justfile_directory() / ".pixi/nix-test")
export NIXFILES_CHECKOUT := justfile_directory()
export NIXFILES_STORE := env("NIXFILES_STORE", "auto")

# Choose the recipe to run interactively
_default:
    -@just --choose

# Lint the embedded recipes and parse Nix without fetching inputs
check:
    #!/usr/bin/env bash
    set -euo pipefail
    just --fmt --check
    for recipe in baseline _syntax check test-workflows test-workflows-nix test-portable-nix _test-portable hosts update-flatpak test-git test-git-nix test-terminals test-terminals-nix _test-tmux test-yazi-direnv test-yazi-direnv-nix _test-yazi-direnv test-starship-gitui test-starship-gitui-nix _test-starship-gitui test-cli-tools test-cli-tools-nix _test-cli-tools test-desktop-tools test-desktop-tools-nix _test-desktop-tools; do
        just --dry-run "$recipe" 2>&1 | shellcheck -s bash -
    done
    just --dry-run link-checkout /tmp/nixfiles-lint-anchor 2>&1 | shellcheck -s bash -
    for recipe in check-host plan build test-host switch; do
        just --dry-run "$recipe" jupiter 2>&1 | shellcheck -s bash -
    done
    just --dry-run diff jupiter /nix/store/previous 2>&1 | shellcheck -s bash -
    just --dry-run _host diff jupiter /nix/store/previous 2>&1 | shellcheck -s bash -
    just --dry-run _activate test jupiter 2>&1 | shellcheck -s bash -
    just --dry-run _nix --version 2>&1 | shellcheck -s bash -
    just --dry-run update-inputs nixpkgs 2>&1 | shellcheck -s bash -
    just --dry-run provision-identity /tmp/nixfiles-identity /mnt 2>&1 | shellcheck -s bash -
    just --dry-run disko moon 2>&1 | shellcheck -s bash -
    just --dry-run generate-hardware moon 2>&1 | shellcheck -s bash -
    just --dry-run _installer moon 2>&1 | shellcheck -s bash -
    just --dry-run test-install-workflows 2>&1 | shellcheck -s bash -
    just --dry-run remap-keyboard 'USB Keyboard' 2>&1 | shellcheck -s bash -
    just --dry-run test-input-remapper 2>&1 | shellcheck -s bash -
    for recipe in dotfiles-diff dotfiles-apply; do
        just --dry-run "$recipe" /tmp/nixfiles-lint-home 2>&1 | shellcheck -s bash -
    done
    just --dry-run _dotfiles diff /tmp/nixfiles-lint-home 2>&1 | shellcheck -s bash -
    just _syntax
    just test-git
    just test-terminals
    just test-yazi-direnv
    just test-starship-gitui
    just test-cli-tools
    just test-desktop-tools
    just test-workflows
    just test-input-remapper
    just test-install-workflows

# Point an explicitly selected user-local anchor at this checkout
link-checkout anchor:
    #!/usr/bin/env bash
    set -euo pipefail
    nixfiles_anchor={{ quote(anchor) }}
    [[ "$nixfiles_anchor" == /* ]] || { printf 'The anchor must be an absolute path.\n' >&2; exit 2; }
    if [[ -e "$nixfiles_anchor" && ! -L "$nixfiles_anchor" ]]; then
        printf 'Refusing to replace a file or directory at %s\n' "$nixfiles_anchor" >&2
        exit 1
    fi
    mkdir -p -- "$(dirname -- "$nixfiles_anchor")"
    ln -sfnT -- "$NIXFILES_CHECKOUT" "$nixfiles_anchor"
    printf '%s -> %s\n' "$nixfiles_anchor" "$NIXFILES_CHECKOUT"

# Exercise native Git settings and chezmoi in a temporary checkout and home
test-git:
    #!/usr/bin/env bash
    set -euo pipefail
    umask 077
    test_dir=$(mktemp -d "${TMPDIR:-/tmp}/nixfiles-git.XXXXXX")
    checkout="$test_dir/checkout one"
    target="$test_dir/home"
    mkdir -p "$checkout/src/dotfiles" "$target"
    cp -R src/dotfiles/. "$checkout/src/dotfiles/"
    cp -R src/chezmoi "$checkout/src/"
    cp justfile "$checkout/justfile"
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git init -q --template= "$checkout"
    touch "$test_dir/chezmoi.toml"

    chez() {
        chezmoi --source "$checkout/src/chezmoi" --working-tree "$checkout" \
            --destination "$target" --config "$test_dir/chezmoi.toml" \
            --cache "$test_dir/cache" --persistent-state "$test_dir/state.boltdb" \
            --no-tty "$@"
    }
    test_git() {
        GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$target/.config/git/config" \
            XDG_CONFIG_HOME="$target/.config" git "$@"
    }

    chez init
    chez diff > "$test_dir/before.diff"
    [[ -s "$test_dir/before.diff" && ! -e "$target/.config/git/config" ]]
    chez apply
    chez verify
    chez diff > "$test_dir/after.diff"
    [[ ! -s "$test_dir/after.diff" ]]
    for file in config ignore; do
        [[ -L "$target/.config/git/$file" ]]
        [[ "$(readlink -f "$target/.config/git/$file")" == "$checkout/src/dotfiles/git/$file" ]]
    done
    test_git config --global --includes --list --show-origin > "$test_dir/origins.txt"
    [[ "$(test_git config --global --includes --get user.email)" == eduardo.farinati@ufrgs.br ]]
    [[ "$(test_git config --global --includes --get push.default)" == upstream ]]
    [[ "$(test_git config --global --includes --get gpg.openpgp.program)" == gpg ]]
    [[ "$(test_git config --global --includes --get-all versionsort.suffix | wc -l)" -eq 6 ]]
    [[ "$(test_git config --global --includes --get-all credential.https://github.com.helper)" == $'\n!gh auth git-credential' ]]

    test_git init -q --template= "$test_dir/repository"
    mkdir -p "$test_dir/repository/.direnv" "$test_dir/repository/.bin"
    touch "$test_dir/repository/.envrc" "$test_dir/repository/scratch.swp" \
        "$test_dir/repository/.direnv/cache" "$test_dir/repository/.bin/tool" \
        "$test_dir/repository/README.md"
    for file in .envrc scratch.swp .direnv/cache .bin/tool; do
        test_git -C "$test_dir/repository" check-ignore -q "$file"
    done
    if test_git -C "$test_dir/repository" check-ignore -q README.md; then
        printf 'Unexpected ignore rule for README.md\n' >&2; exit 1
    fi

    git config --file "$target/.config/git/config.local" user.email local@example.invalid
    [[ "$(test_git config --global --includes --get user.email)" == local@example.invalid ]]
    anchor="$test_dir/data/nixfiles"
    just --justfile "$checkout/justfile" link-checkout "$anchor"
    ln -s "$anchor/src/dotfiles/git/config" "$test_dir/live-config"
    mv "$checkout" "$test_dir/checkout moved"
    checkout="$test_dir/checkout moved"
    [[ ! -e "$test_dir/live-config" ]]
    just --justfile "$checkout/justfile" link-checkout "$anchor"
    [[ -f "$test_dir/live-config" ]]
    chez apply
    chez verify
    [[ "$(test_git config --global --includes --get user.email)" == local@example.invalid ]]
    git config --file "$checkout/src/dotfiles/git/config" test.live yes
    [[ "$(test_git config --global --includes --get test.live)" == yes ]]

    mkdir "$test_dir/existing-directory"
    printf 'keep me\n' > "$test_dir/existing-file"
    for path in "$test_dir/existing-directory" "$test_dir/existing-file" relative; do
        if just link-checkout "$path" > "$test_dir/refusal.log" 2>&1; then
            printf 'Anchor setup accepted an unsafe destination: %s\n' "$path" >&2; exit 1
        fi
    done
    [[ -d "$test_dir/existing-directory" && "$(cat "$test_dir/existing-file")" == 'keep me' ]]
    printf 'PASS: Git settings, ignores, local overrides, live edits, relocation, and anchor guards.\nReport: %s\n' "$test_dir"

# Build and inspect Home Manager's Git links without activating a home
test-git-nix:
    #!/usr/bin/env bash
    set -euo pipefail
    umask 077
    [[ "$NIXFILES_TEST_ROOT" == /* ]] || { printf 'NIXFILES_TEST_ROOT must be absolute.\n' >&2; exit 2; }
    mkdir -p "$NIXFILES_TEST_ROOT/cache"
    export XDG_CACHE_HOME="$NIXFILES_TEST_ROOT/cache"
    nix_cmd=(nix --extra-experimental-features 'nix-command flakes'
        --store "$NIXFILES_TEST_ROOT" --option build-users-group '')
    test_dir=$(mktemp -d "${TMPDIR:-/tmp}/nixfiles-git-nix.XXXXXX")
    test_home="$test_dir/home"
    checkout="$test_dir/checkout"
    anchor="$test_home/.local/share/nixfiles"
    mkdir -p "$checkout/src/dotfiles" "$test_home/.config/git"
    cp -R src/dotfiles/git "$checkout/src/dotfiles/"
    cp justfile "$checkout/justfile"
    just --justfile "$checkout/justfile" link-checkout "$anchor"
    eval_args=(--impure --file src/tests/git-pilot.nix --argstr testHome "$test_home")

    "${nix_cmd[@]}" eval "${eval_args[@]}" --json metadata > "$test_dir/metadata.json"
    jq -e --arg anchor "$anchor" '
        .anchor == $anchor and .generatedGit == false and
        .configText == null and .ignoreText == null and
        .configFiles == {"git/config":"git/config", "git/ignore":"git/ignore"} and
        (.packages | index("git") != null) and (.packages | index("gnupg") != null)
    ' "$test_dir/metadata.json" > /dev/null
    files=$("${nix_cmd[@]}" build "${eval_args[@]}" --no-link --print-out-paths files)
    for file in config ignore; do
        source=$(readlink "$NIXFILES_TEST_ROOT$files/.config/git/$file")
        [[ "$source" == /nix/store/* ]]
        [[ "$(readlink "$NIXFILES_TEST_ROOT$source")" == "$anchor/src/dotfiles/git/$file" ]]
        ln -s "$NIXFILES_TEST_ROOT$source" "$test_home/.config/git/$file"
    done
    [[ "$(GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$test_home/.config/git/config" git config --global --includes --get user.email)" == eduardo.farinati@ufrgs.br ]]
    mv "$checkout" "$test_dir/checkout moved"
    just --justfile "$test_dir/checkout moved/justfile" link-checkout "$anchor"
    [[ -f "$test_home/.config/git/config" && -f "$test_home/.config/git/ignore" ]]

    "${nix_cmd[@]}" eval "${eval_args[@]}" --argstr anchor "$test_dir/custom" --json metadata \
        | jq -e --arg anchor "$test_dir/custom" '.anchor == $anchor' > /dev/null
    if "${nix_cmd[@]}" eval "${eval_args[@]}" --argstr anchor relative --json metadata > "$test_dir/invalid-anchor.log" 2>&1; then
        printf 'Home Manager accepted a relative anchor.\n' >&2; exit 1
    fi
    [[ "$(cat "$test_dir/invalid-anchor.log")" == *dotfiles.anchor* ]]
    printf 'PASS: built Home Manager links, relocation, custom anchor, and anchor validation.\nReport: %s\n' "$test_dir"

# Exercise shared terminal files through chezmoi without changing this home
test-terminals:
    #!/usr/bin/env bash
    set -euo pipefail
    umask 077
    test_dir=$(mktemp -d "${TMPDIR:-/tmp}/nixfiles-terminals.XXXXXX")
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
    for file in tmux/tmux.conf ghostty/config; do
        [[ -L "$target/.config/$file" ]]
        [[ "$(readlink -f "$target/.config/$file")" == "$checkout/src/dotfiles/$file" ]]
    done
    export NIXFILES_TERMINAL_CONFIG="$target/.config"
    export NIXFILES_TERMINAL_TEST_DIR="$test_dir"
    just _test-tmux
    mv "$checkout" "$test_dir/checkout moved"
    checkout="$test_dir/checkout moved"
    chez apply
    chez verify
    [[ -f "$target/.config/tmux/tmux.conf" && -f "$target/.config/ghostty/config" ]]
    if grep -n '/nix/store/' "$checkout/src/dotfiles/tmux/tmux.conf" "$checkout/src/dotfiles/ghostty/config"; then
        printf 'Native terminal config contains a store path.\n' >&2; exit 1
    fi
    printf 'PASS: terminal symlinks, tmux behavior, live edits, and checkout relocation.\nReport: %s\n' "$test_dir"

# Shared runtime checks; always uses a private server and explicit config
_test-tmux:
    #!/usr/bin/env bash
    set -euo pipefail
    socket="$NIXFILES_TERMINAL_TEST_DIR/tmux.sock"
    trap 'tmux -S "$socket" kill-server 2>/dev/null || true' EXIT
    export XDG_CONFIG_HOME="$NIXFILES_TERMINAL_CONFIG"
    tmux -S "$socket" -f /dev/null new-session -d -s terminal-test -x 100 -y 30 'sleep 300'
    tmux -S "$socket" source-file "$XDG_CONFIG_HOME/tmux/tmux.conf" > "$NIXFILES_TERMINAL_TEST_DIR/tmux-load.log" 2>&1
    [[ ! -s "$NIXFILES_TERMINAL_TEST_DIR/tmux-load.log" ]]
    [[ "$(tmux -S "$socket" show-options -gv prefix)" == C-Space ]]
    [[ "$(tmux -S "$socket" show-options -gv default-terminal)" == tmux-256color ]]
    [[ "$(tmux -S "$socket" show-options -gv base-index)" == 1 ]]
    [[ "$(tmux -S "$socket" show-window-options -gv pane-base-index)" == 1 ]]
    [[ "$(tmux -S "$socket" show-options -gv history-limit)" == 10000 ]]
    [[ "$(tmux -S "$socket" show-options -sv escape-time)" == 0 ]]
    [[ "$(tmux -S "$socket" show-options -gv mouse)" == on ]]
    [[ "$(tmux -S "$socket" show-options -gv status-position)" == top ]]
    [[ "$(tmux -S "$socket" show-window-options -gv mode-keys)" == vi ]]
    # Query full tables: the optional key filter differs across tmux versions.
    prefix_keys=$(tmux -S "$socket" list-keys -T prefix)
    copy_keys=$(tmux -S "$socket" list-keys -T copy-mode-vi)
    grep -E 'prefix[[:blank:]]+v[[:blank:]]+split-window -h' <<<"$prefix_keys" >/dev/null
    grep -E 'prefix[[:blank:]]+x[[:blank:]]+kill-pane' <<<"$prefix_keys" >/dev/null
    grep -E 'copy-mode-vi[[:blank:]]+y[[:blank:]]+.*xsel --clipboard' <<<"$copy_keys" >/dev/null
    if [[ "${NIXFILES_TERMINAL_PLUGINS:-0}" == 1 ]]; then
        [[ "$(tmux -S "$socket" show-options -gv @thm_bg)" == '#1e1e2e' ]]
        [[ "$(tmux -S "$socket" show-options -gv @catppuccin_window_status_style)" == custom ]]
        [[ "$(tmux -S "$socket" show-options -gv @catppuccin_window_text)" == '#W' ]]
        [[ "$(tmux -S "$socket" show-options -gv @catppuccin_window_left_separator)" == '' ]]
        [[ "$(tmux -S "$socket" show-options -gv status-right)" == '#{E:@catppuccin_status_session}' ]]
        grep -E 'prefix[[:blank:]]+S[[:blank:]]+.*resurrect.*save.sh' <<<"$prefix_keys" >/dev/null
        grep -E 'prefix[[:blank:]]+R[[:blank:]]+.*resurrect.*restore.sh' <<<"$prefix_keys" >/dev/null
    fi
    printf '\nset -g @nixfiles-live-test yes\n' >> "$XDG_CONFIG_HOME/tmux/tmux.conf"
    tmux -S "$socket" source-file "$XDG_CONFIG_HOME/tmux/tmux.conf" > "$NIXFILES_TERMINAL_TEST_DIR/tmux-reload.log" 2>&1
    [[ ! -s "$NIXFILES_TERMINAL_TEST_DIR/tmux-reload.log" ]]
    [[ "$(tmux -S "$socket" show-options -gv @nixfiles-live-test)" == yes ]]

# Build Home Manager's links and load configs with pinned tmux/plugins/Ghostty
test-terminals-nix:
    #!/usr/bin/env bash
    set -euo pipefail
    umask 077
    [[ "$NIXFILES_TEST_ROOT" == /* ]] || { printf 'NIXFILES_TEST_ROOT must be absolute.\n' >&2; exit 2; }
    mkdir -p "$NIXFILES_TEST_ROOT/cache"
    export XDG_CACHE_HOME="$NIXFILES_TEST_ROOT/cache"
    nix_cmd=(nix --extra-experimental-features 'nix-command flakes'
        --store "$NIXFILES_TEST_ROOT" --option build-users-group '')
    test_dir=$(mktemp -d "${TMPDIR:-/tmp}/nixfiles-terminals-nix.XXXXXX")
    test_home="$test_dir/home"
    checkout="$test_dir/checkout one"
    anchor="$test_home/.local/share/nixfiles"
    mkdir -p "$checkout/src/dotfiles" "$test_home/.config/tmux/plugins" "$test_home/.config/ghostty"
    cp -R src/dotfiles/tmux src/dotfiles/ghostty "$checkout/src/dotfiles/"
    cp justfile "$checkout/justfile"
    just --justfile "$checkout/justfile" link-checkout "$anchor"
    eval_args=(--impure --file src/tests/terminal-pilot.nix --argstr testHome "$test_home")
    "${nix_cmd[@]}" eval "${eval_args[@]}" --json metadata > "$test_dir/metadata.json"
    jq -e --arg anchor "$anchor" '
        .anchor == $anchor and .generatedTmux == false and .tmuxText == null and .ghosttyText == null and .ghosttySettings == {} and
        .configFiles == {"tmux/tmux.conf":"tmux/tmux.conf", "ghostty/config":"ghostty/config"} and
        (.packages | index("tmux") != null) and (.packages | index("ghostty") != null) and
        (.packages | index("xsel") != null) and (.packages | index("cascadia-code") != null) and
        (.sessionVariables.TMUX_TMPDIR | contains("XDG_RUNTIME_DIR")) and
        (.ghosttyShellIntegration.bash | contains("shell-integration/bash/ghostty.bash")) and
        (.ghosttyShellIntegration.zsh | contains("shell-integration/zsh/ghostty-integration"))
    ' "$test_dir/metadata.json" > /dev/null
    files=$("${nix_cmd[@]}" build "${eval_args[@]}" --no-link --print-out-paths files)
    for file in tmux/tmux.conf ghostty/config; do
        source=$(readlink "$NIXFILES_TEST_ROOT$files/.config/$file")
        [[ "$(readlink "$NIXFILES_TEST_ROOT$source")" == "$anchor/src/dotfiles/$file" ]]
        ln -s "$NIXFILES_TEST_ROOT$source" "$test_home/.config/$file"
    done
    # These links are consumed inside the relocated store's mount namespace.
    for plugin in catppuccin resurrect; do
        source=$(jq -r --arg plugin "$plugin" '.plugins[$plugin]' "$test_dir/metadata.json")
        [[ "$(readlink "$NIXFILES_TEST_ROOT$files/.config/tmux/plugins/$plugin")" == "$source" ]]
        ln -s "$source" "$test_home/.config/tmux/plugins/$plugin"
    done
    mv "$checkout" "$test_dir/checkout moved"
    just --justfile "$test_dir/checkout moved/justfile" link-checkout "$anchor"
    [[ -f "$test_home/.config/tmux/tmux.conf" && -f "$test_home/.config/ghostty/config" ]]
    just --dry-run _test-tmux 2> "$test_dir/tmux-runtime.sh"
    export NIXFILES_TERMINAL_CONFIG="$test_home/.config"
    export NIXFILES_TERMINAL_TEST_DIR="$test_dir"
    export NIXFILES_TERMINAL_PLUGINS=1
    "${nix_cmd[@]}" shell "${eval_args[@]}" runtime -c bash "$test_dir/tmux-runtime.sh"
    # Validate without opening a window; font matching uses only the declared font.
    font_directory=$(jq -r '.fontDirectory' "$test_dir/metadata.json")
    cat > "$test_dir/fonts.conf" <<EOF
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig><dir>$font_directory</dir><cachedir>$test_dir/font-cache</cachedir></fontconfig>
    EOF
    # shellcheck disable=SC2016
    "${nix_cmd[@]}" shell "${eval_args[@]}" runtime -c bash -c \
        'ghostty +validate-config --config-file="$1" &&
         [[ "$(FONTCONFIG_FILE="$2" fc-match -f "%{family[0]}" "Cascadia Code NF")" == "Cascadia Code NF" ]]' \
        bash "$test_home/.config/ghostty/config" "$test_dir/fonts.conf" >"$test_dir/ghostty-load.log" 2>&1
    printf 'PASS: Home Manager links and shell integration, pinned tmux plugins, Ghostty config, and Cascadia Code NF.\nReport: %s\n' "$test_dir"

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
    cp justfile "$checkout/justfile"
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
    cp justfile "$checkout/justfile"
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
    cp justfile "$checkout/justfile"
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
    cp justfile "$checkout/justfile"
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

# Parse tracked and unignored Nix sources without a real store
_syntax:
    #!/usr/bin/env bash
    set -euo pipefail
    status=0
    count=0
    while IFS= read -r -d '' file; do
        # Git still lists tracked files removed from the working tree.
        [[ -f "$file" ]] || continue
        printf 'Parsing %s\n' "$file"
        if ! nix-instantiate --store dummy:// --parse "$file" >/dev/null; then
            status=1
        fi
        count=$((count + 1))
    done < <(git ls-files --cached --others --exclude-standard -z -- '*.nix')
    printf 'Parsed %s Nix files.\n' "$count"
    exit "$status"

# Capture all three hosts' evaluation, warnings, package names, and build plans
baseline:
    #!/usr/bin/env bash
    set -euo pipefail
    umask 077
    case "$NIXFILES_TEST_ROOT" in
        /*) ;;
        *) printf 'NIXFILES_TEST_ROOT must be an absolute path.\n' >&2; exit 2 ;;
    esac
    mkdir -p "$NIXFILES_TEST_ROOT/cache"
    export XDG_CACHE_HOME="$NIXFILES_TEST_ROOT/cache"
    report_dir=$(mktemp -d "${TMPDIR:-/tmp}/nixfiles-baseline.XXXXXX")
    summary="$report_dir/summary.md"
    nix_cmd=(nix --extra-experimental-features 'nix-command flakes'
        --store "$NIXFILES_TEST_ROOT" --option build-users-group '')
    failures=0

    {
        printf '# Nixfiles baseline\n\n'
        printf 'Captured: %s\n\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
        printf 'Commit: %s\n\n' "$(git rev-parse HEAD)"
        printf 'Branch: %s\n\n' "$(git branch --show-current)"
        printf 'Lock SHA-256: %s\n\n' "$(sha256sum flake.lock | cut -d ' ' -f 1)"
        printf 'Test store root: %s\n\n' "$NIXFILES_TEST_ROOT"
        printf 'Working tree at capture:\n\n```text\n'
        git status --short
        printf '```\n\n'
        printf 'Commands retain the lockfile and never activate a system.\n'
        printf 'Evaluation can fetch pinned sources or build evaluation dependencies.\n'
        printf 'Build plans are not completed system builds.\n\n'
        printf '| Check | Result | Log |\n| --- | --- | --- |\n'
    } >"$summary"

    run_check() {
        local name=$1
        shift
        local status=0
        printf 'Running %s...\n' "$name"
        {
            printf 'Command: '
            printf '%q ' "$@"
            printf '\n\n'
            "$@"
        } >"$report_dir/$name.log" 2>&1 || status=$?
        if (( status == 0 )); then
            printf '| %s | PASS | [%s.log](%s.log) |\n' "$name" "$name" "$name" >>"$summary"
        else
            printf '| %s | FAIL (exit %s) | [%s.log](%s.log) |\n' "$name" "$status" "$name" "$name" >>"$summary"
            failures=$((failures + 1))
        fi
    }

    run_check nix-version nix --version
    run_check syntax just _syntax
    run_check outputs "${nix_cmd[@]}" flake show --no-update-lock-file --json .

    for host in jupiter mars moon; do
        config=".#nixosConfigurations.$host.config"
        run_check "$host-metadata" "${nix_cmd[@]}" eval --no-update-lock-file --json "$config" \
            --apply 'config: {
                hostName = config.networking.hostName;
                systemStateVersion = config.system.stateVersion;
                homeStateVersion = config.home-manager.users.skylab.home.stateVersion;
                warnings = config.warnings;
            }'
        run_check "$host-eval" "${nix_cmd[@]}" eval --no-update-lock-file --raw "$config.system.build.toplevel.drvPath"
        run_check "$host-system-packages" "${nix_cmd[@]}" eval --no-update-lock-file --json "$config.environment.systemPackages" \
            --apply 'packages: map (package: package.name) packages'
        run_check "$host-home-packages" "${nix_cmd[@]}" eval --no-update-lock-file --json "$config.home-manager.users.skylab.home.packages" \
            --apply 'packages: map (package: package.name) packages'
        run_check "$host-home-files" "${nix_cmd[@]}" eval --no-update-lock-file --json "$config.home-manager.users.skylab" \
            --apply 'home: {
                shellAliases = home.home.shellAliases;
                sessionVariables = home.home.sessionVariables;
                sessionPath = home.home.sessionPath;
                files = builtins.mapAttrs (_: file: {
                    inherit (file) target recursive executable force;
                    source = toString file.source;
                    textHash = if file.text == null then null else builtins.hashString "sha256" file.text;
                }) home.home.file;
            }'
        run_check "$host-policy" "${nix_cmd[@]}" eval --impure --no-update-lock-file --json "$config" \
            --apply 'import ./src/tests/host-policy.nix'
        run_check "$host-build-plan" "${nix_cmd[@]}" build --no-update-lock-file --dry-run --no-link "$config.system.build.toplevel"
    done

    run_check hyprland-eval "${nix_cmd[@]}" eval --impure --json --file src/tests/hyprland.nix

    # Materialize imports via host evaluation before flake check's read-only pass.
    run_check flake-check "${nix_cmd[@]}" flake check --no-update-lock-file --no-build --keep-going .

    printf '\n%s failing checks. Full report: %s\n' "$failures" "$summary"
    if (( failures > 0 )); then
        exit 1
    fi

# List the hosts declared by this checkout
hosts:
    #!/usr/bin/env bash
    set -euo pipefail
    just _nix eval --no-update-lock-file --json .#nixosConfigurations --apply builtins.attrNames | jq -r '.[]'

# Evaluate a selected host and report its warnings and system derivation
[positional-arguments]
check-host host:
    #!/usr/bin/env bash
    set -euo pipefail
    just _host check "$1"

# Show the selected host's build plan without building or activating it
[positional-arguments]
plan host:
    #!/usr/bin/env bash
    set -euo pipefail
    just _host plan "$1"

# Build a selected host without creating a result link or activating it
[positional-arguments]
build host:
    #!/usr/bin/env bash
    set -euo pipefail
    just _host build "$1"

# ERASE, format, and mount a host's configured disks using its pinned Disko script
[positional-arguments]
disko host:
    #!/usr/bin/env bash
    set -euo pipefail
    just _installer "$1"
    config=".#nixosConfigurations.$1.config"
    disks=$(just _nix eval --no-update-lock-file --raw "$config.disko.devices.disk" \
        --apply 'disks: builtins.concatStringsSep "\n" (map (disk: disk.device) (builtins.attrValues disks))')
    printf 'ERASE, format, and mount the configured disks for %s:\n%s\n' "$1" "$disks" >&2
    script=$(just _nix build --no-update-lock-file --no-link --print-out-paths \
        --max-jobs 1 --cores 2 "$config.system.build.diskoScript")
    sudo "$script"

# Generate a new hardware module from this machine, without duplicating Disko mounts
[positional-arguments]
generate-hardware host root="/mnt":
    #!/usr/bin/env bash
    set -euo pipefail
    just _installer "$1"
    [[ "$2" == /* ]] || { printf 'Supply an absolute mounted target root.\n' >&2; exit 2; }
    mountpoint -q -- "$2" || { printf 'Target root is not mounted: %s\n' "$2" >&2; exit 2; }
    relative="src/hosts/$1/hardware-configuration.nix"
    destination="$NIXFILES_CHECKOUT/$relative"
    [[ ! -e "$destination" && ! -L "$destination" ]] || {
        printf 'Hardware configuration already exists; review it instead of overwriting: %s\n' "$destination" >&2
        exit 2
    }
    temporary=$(mktemp "$NIXFILES_CHECKOUT/src/hosts/$1/.hardware-configuration.XXXXXX")
    trap 'rm -f -- "$temporary"' EXIT
    # Only the scan needs root; the output belongs to the checkout's owner.
    # shellcheck disable=SC2024
    sudo nixos-generate-config --root "$2" --no-filesystems --show-hardware-config > "$temporary"
    [[ -s "$temporary" ]]
    nix-instantiate --store dummy:// --parse "$temporary" >/dev/null
    mv -- "$temporary" "$destination"
    git -C "$NIXFILES_CHECKOUT" add --intent-to-add -- "$relative"
    printf 'Generated %s; review it before installation and commit it afterward.\n' "$destination"

# Build the selected host and compare it with an explicit previous closure
[positional-arguments]
diff host previous:
    #!/usr/bin/env bash
    set -euo pipefail
    just _host diff "$1" "$2"

# Activate temporarily on the matching NixOS machine (does not set boot default)
[positional-arguments]
test-host host:
    #!/usr/bin/env bash
    set -euo pipefail
    just _activate test "$1"

# Activate and set the boot default on the matching NixOS machine
[positional-arguments]
switch host:
    #!/usr/bin/env bash
    set -euo pipefail
    just _activate switch "$1"

# Update only explicitly named direct flake inputs; inspect the lock diff afterward
[positional-arguments]
update-inputs +inputs:
    #!/usr/bin/env bash
    set -euo pipefail
    for input in "$@"; do
        jq -e --arg input "$input" '.nodes[.root].inputs | has($input)' flake.lock >/dev/null || {
            printf 'Unknown direct input: %s\n' "$input" >&2
            exit 2
        }
    done
    just _nix flake update "$@"
    git diff -- flake.lock
    printf '\nReview flake.lock, then run check and baseline before building.\n'

# Update Flatpak applications independently of Nix and system activation
update-flatpak:
    #!/usr/bin/env bash
    set -euo pipefail
    flatpak update

# Install an existing private key on this host or inside a mounted target root
[positional-arguments]
provision-identity source target-root="/":
    #!/usr/bin/env bash
    set -euo pipefail
    [[ "$1" == /* && "$2" == /* ]] || { printf 'Supply absolute paths for the private key and target root.\n' >&2; exit 2; }
    source=$(realpath -e -- "$1")
    target_root=$(realpath -e -- "$2")
    [[ -f "$source" && -d "$target_root" ]] || { printf 'Supply an existing private-key file and target directory.\n' >&2; exit 2; }
    directory="${target_root%/}/var/lib/agenix"
    sudo bash -s -- "$source" "$directory" <<'SH'
    set -euo pipefail
    source="$1"
    directory="$2"
    destination="$directory/identity"
    [[ ! -L "$directory" && ! -L "$destination" ]] || { printf 'Refusing a symlink at the identity destination.\n' >&2; exit 1; }
    if [[ -e "$destination" ]]; then
        [[ -f "$destination" ]] && cmp -s -- "$source" "$destination" || {
            printf 'A different identity already exists at %s; refusing to replace it.\n' "$destination" >&2
            exit 1
        }
    fi
    install -d -m 0700 -o root -g root -- "$directory"
    if [[ -e "$destination" ]]; then
        chown root:root -- "$destination"
        chmod 0600 -- "$destination"
    else
        install -m 0600 -o root -g root -- "$source" "$destination"
    fi
    printf 'Identity provisioned at %s\n' "$destination"
    SH

# Copy the shared remaps to a keyboard and enable its autoload entry
[positional-arguments]
remap-keyboard device model="":
    #!/usr/bin/env bash
    set -euo pipefail
    python=(python3)
    if ! command -v python3 >/dev/null; then
        python=(just _nix shell --no-update-lock-file --inputs-from "$NIXFILES_CHECKOUT" nixpkgs#python3 -c python3)
    fi
    "${python[@]}" - "$NIXFILES_CHECKOUT/src/dotfiles/input-remapper/ergo_remaps.json" "$1" "$2" <<'PY'
    import json, os, sys, tempfile
    from pathlib import Path

    template, device, model = sys.argv[1:]
    model = model or device
    if not device.strip() or any(c in device for c in '\x00\n\r'):
        raise SystemExit('Supply the keyboard name shown by Input Remapper.')
    # Match Input Remapper's directory-name sanitization.
    folder = model.translate(str.maketrans({c: '_' for c in '/\\?%*:|"<>'}))
    if folder in ('', '.', '..') or any(c in folder for c in '\x00\n\r'):
        raise SystemExit('Invalid keyboard model name.')
    root = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'input-remapper-2'
    config_file = root / 'config.json'
    config = json.loads(config_file.read_text()) if config_file.exists() else {'version': '2.2.1'}
    if not isinstance(config, dict) or not isinstance(config.get('autoload', {}), dict):
        raise SystemExit('Expected an object with an autoload object in config.json; no files changed.')
    preset = json.loads(Path(template).read_text())
    config.setdefault('autoload', {})[device] = 'ergo_remaps'

    def save(path, value):
        data = (json.dumps(value, indent=4) + '\n').encode()
        if path.exists() and path.read_bytes() == data:
            return
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists():
            fd, backup = tempfile.mkstemp(prefix=path.name + '.', suffix='.bak', dir=path.parent)
            with os.fdopen(fd, 'wb') as stream:
                stream.write(path.read_bytes())
            print(f'Backup: {backup}')
        fd, temporary = tempfile.mkstemp(prefix='.' + path.name + '.', dir=path.parent)
        try:
            with os.fdopen(fd, 'wb') as stream:
                stream.write(data)
            os.replace(temporary, path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)

    preset_file = root / 'presets' / folder / 'ergo_remaps.json'
    save(preset_file, preset)
    save(config_file, config)
    print(f'Configured {device}: {preset_file}')
    print('Apply ergo_remaps in Input Remapper now, or reconnect the keyboard after your next desktop login.')
    PY

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
        shutil.copy(original / 'justfile', checkout)
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

# Preview portable dotfile changes in an explicitly selected home
[positional-arguments]
dotfiles-diff destination:
    #!/usr/bin/env bash
    set -euo pipefail
    just _dotfiles diff "$1"

# Apply portable dotfiles on a home owned by chezmoi rather than Home Manager
[positional-arguments]
dotfiles-apply destination:
    #!/usr/bin/env bash
    set -euo pipefail
    just _dotfiles apply "$1"

[positional-arguments]
_nix +args:
    #!/usr/bin/env bash
    set -euo pipefail
    store="$NIXFILES_STORE"
    if [[ "$store" == auto ]]; then
        if [[ -e /etc/NIXOS ]]; then
            store=daemon
        else
            store="$NIXFILES_TEST_ROOT"
        fi
    fi
    nix_cmd=(nix --extra-experimental-features 'nix-command flakes' --store "$store")
    case "$store" in
        daemon) ;;
        /*)
            mkdir -p -- "$store/cache"
            export XDG_CACHE_HOME="$store/cache"
            nix_cmd+=(--option build-users-group '')
            ;;
        *) printf 'NIXFILES_STORE must be auto, daemon, or an absolute writable store root.\n' >&2; exit 2 ;;
    esac
    exec "${nix_cmd[@]}" "$@"

[positional-arguments]
_installer host:
    #!/usr/bin/env bash
    set -euo pipefail
    [[ "$1" =~ ^[a-zA-Z0-9_-]+$ && -f "$NIXFILES_CHECKOUT/src/hosts/$1/default.nix" ]] || {
        printf 'Supply an existing host name from src/hosts.\n' >&2; exit 2
    }
    [[ -e /etc/NIXOS ]] || { printf 'Run installer recipes on the NixOS live system, outside a distrobox.\n' >&2; exit 2; }
    case "$NIXFILES_STORE" in
        auto|daemon) ;;
        *) printf 'Installer recipes require the system daemon store.\n' >&2; exit 2 ;;
    esac

[positional-arguments]
_host action host previous="":
    #!/usr/bin/env bash
    set -euo pipefail
    action="$1"
    host="$2"
    previous="${3:-}"
    case "$action" in check|plan|build|diff) ;; *) exit 2 ;; esac
    # Host names become Nix attribute selectors, so validate both syntax and membership.
    [[ "$host" =~ ^[a-zA-Z0-9_-]+$ ]] || { printf 'Invalid host name: %s\n' "$host" >&2; exit 2; }
    declared=$(just _nix eval --no-update-lock-file --json .#nixosConfigurations --apply builtins.attrNames)
    jq -e --arg host "$host" 'index($host) != null' <<<"$declared" >/dev/null || {
        printf 'Unknown host: %s. Use hosts to list configured machines.\n' "$host" >&2
        exit 2
    }
    config=".#nixosConfigurations.$host.config"
    case "$action" in
        check)
            just _nix eval --no-update-lock-file --json "$config" --apply 'config: {
                hostName = config.networking.hostName;
                stateVersion = config.system.stateVersion;
                warnings = config.warnings;
                derivation = config.system.build.toplevel.drvPath;
            }'
            ;;
        plan) just _nix build --no-update-lock-file --dry-run --no-link "$config.system.build.toplevel" ;;
        build) just _nix build --no-update-lock-file --no-link --print-out-paths "$config.system.build.toplevel" ;;
        diff)
            [[ "$previous" == /nix/store/* ]] || { printf 'Supply the previous logical /nix/store closure path.\n' >&2; exit 2; }
            candidate=$(just _nix build --no-update-lock-file --no-link --print-out-paths "$config.system.build.toplevel")
            just _nix store diff-closures "$previous" "$candidate"
            ;;
    esac

[positional-arguments]
_activate action host:
    #!/usr/bin/env bash
    set -euo pipefail
    action="$1"
    host="$2"
    case "$action" in test|switch) ;; *) exit 2 ;; esac
    [[ -e /etc/NIXOS ]] || { printf 'Activation requires the matching NixOS machine. Deployment is deferred here.\n' >&2; exit 2; }
    case "$NIXFILES_STORE" in auto|daemon) ;; *) printf 'Activation requires the system daemon store.\n' >&2; exit 2 ;; esac
    [[ "$(hostname)" == "$host" ]] || { printf 'Selected host does not match this machine.\n' >&2; exit 2; }
    just _host check "$host" >&2
    rebuild=$(command -v nixos-rebuild)
    sudo "$rebuild" "$action" --flake ".#$host" --no-update-lock-file

[positional-arguments]
_dotfiles action destination:
    #!/usr/bin/env bash
    set -euo pipefail
    umask 077
    action="$1"
    destination="$2"
    case "$action" in diff|apply) ;; *) exit 2 ;; esac
    [[ "$destination" == /* ]] || { printf 'Supply an absolute destination home.\n' >&2; exit 2; }
    destination=$(realpath -m -- "$destination")
    key=$(printf '%s' "$destination" | sha256sum | cut -d ' ' -f 1)
    state="$NIXFILES_CHECKOUT/.pixi/chezmoi/$key"
    mkdir -p -- "$state"
    touch "$state/chezmoi.toml"
    chez=(chezmoi --source "$NIXFILES_CHECKOUT/src/chezmoi" --working-tree "$NIXFILES_CHECKOUT"
        --destination "$destination" --config "$state/chezmoi.toml"
        --cache "$state/cache" --persistent-state "$state/state.boltdb" --no-tty)
    "${chez[@]}" init
    "${chez[@]}" "$action"

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
        (checkout / 'justfile').write_text(source.read_text().replace('/etc/NIXOS', shlex.quote(str(marker))))
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
            print('/dev/fixture-only')
        else:
            sys.exit(1)
    elif name == 'sudo':
        if args == ['/nix/store/00000000000000000000000000000000-fixture-disko']:
            sys.exit(0)  # Never execute a Disko script.
        if args and args[0] == 'nixos-generate-config':
            os.execvp(args[0], args)
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

        def run(*args, success=True, **changes):
            result = subprocess.run(['just', '--justfile', str(checkout / 'justfile'), *args],
                                    env=dict(environment, **changes), capture_output=True, text=True)
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
        run('disko', 'probe')
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
    print('Installer workflows passed: NixOS/store/host guards, pinned Disko dispatch, scan failures, hardware parsing, Git inclusion, overwrite refusal, and automatic Moon import. No real disks or privileged tools used.')
    PY

# Test workflow dispatch with stub Nix commands and real temporary chezmoi homes
test-workflows:
    #!/usr/bin/env bash
    set -euo pipefail
    umask 077
    test_dir=$(mktemp -d "${TMPDIR:-/tmp}/nixfiles-workflows.XXXXXX")
    checkout="$test_dir/checkout one"
    target="$test_dir/home one"
    mkdir -p "$checkout/src" "$target" "$test_dir/bin"
    cp justfile "$checkout/justfile"
    cp -R src/chezmoi src/dotfiles "$checkout/src/"
    cp flake.lock "$checkout/flake.lock"
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git init -q --template= "$checkout"
    export NIXFILES_WORKFLOW_LOG="$test_dir/commands.jsonl"
    cat >"$test_dir/bin/nix" <<'PY'
    #!/usr/bin/env python3
    import json, os, sys
    args = sys.argv[1:]
    with open(os.environ["NIXFILES_WORKFLOW_LOG"], "a") as log:
        log.write(json.dumps(args) + "\n")
    if "eval" in args:
        print('["probe"]' if "builtins.attrNames" in args else '{"hostName":"probe","warnings":[]}')
    elif "build" in args and "--dry-run" not in args:
        print("/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-probe-2")
    PY
    for command in sudo nixos-rebuild flatpak; do
        cat >"$test_dir/bin/$command" <<'SH'
    #!/usr/bin/env bash
    printf '%s\n' "${0##*/}" >>"$NIXFILES_WORKFLOW_LOG.external"
    [[ "${0##*/}" == flatpak ]]
    SH
    done
    chmod +x "$test_dir/bin/"*
    original_path="$PATH"
    export PATH="$test_dir/bin:$PATH"
    export NIXFILES_TEST_ROOT="$test_dir/store with spaces"
    export NIXFILES_STORE="$NIXFILES_TEST_ROOT"
    run() { just --justfile "$checkout/justfile" "$@"; }
    reject() {
        if run "$@" >"$test_dir/rejected.log" 2>&1; then
            printf 'Unexpected success: %s\n' "$*" >&2
            exit 1
        fi
    }
    [[ "$(run hosts)" == probe ]]
    run check-host probe | jq -e '.hostName == "probe"' >/dev/null
    run plan probe
    [[ "$(run build probe)" == /nix/store/*-probe-2 ]]
    run diff probe /nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-probe-1
    reject build
    reject build missing
    reject build 'probe; touch PWNED'
    reject diff probe relative
    reject update-inputs
    reject update-inputs nixpkgs unknown
    reject update-inputs --all
    run update-inputs nixpkgs home-manager >"$test_dir/update.log"
    NIXFILES_STORE=auto run hosts >"$test_dir/auto.log"
    NIXFILES_STORE=daemon run hosts >"$test_dir/daemon.log"
    NIXFILES_STORE=relative reject hosts
    other_host="$(hostname)-workflow-other"
    reject switch "$other_host"
    reject test-host "$other_host"
    # On other operating systems, even the current hostname cannot activate.
    if [[ ! -e /etc/NIXOS ]]; then
        reject switch "$(hostname)"
        reject test-host "$(hostname)"
    fi
    [[ ! -e "$NIXFILES_WORKFLOW_LOG.external" && ! -e "$checkout/PWNED" ]]
    run update-flatpak
    [[ "$(cat "$NIXFILES_WORKFLOW_LOG.external")" == flatpak ]]
    python3 - <<'PY'
    import json, os
    calls = [json.loads(line) for line in open(os.environ["NIXFILES_WORKFLOW_LOG"])]
    updates = [args for args in calls if "update" in args]
    assert len(updates) == 1 and updates[0][-4:] == ["flake", "update", "nixpkgs", "home-manager"]
    builds = [args for args in calls if "build" in args]
    assert len(builds) == 3 and all("--no-link" in args for args in builds)
    assert sum("--dry-run" in args for args in builds) == 1
    assert all("--no-update-lock-file" in args for args in calls if "eval" in args or "build" in args)
    diffs = [args for args in calls if "diff-closures" in args]
    assert len(diffs) == 1 and diffs[0][-2:] == [
        "/nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-probe-1",
        "/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-probe-2"]
    assert calls[-1][calls[-1].index("--store") + 1] == "daemon"
    assert "build-users-group" not in calls[-1]
    auto_store = calls[-2][calls[-2].index("--store") + 1]
    assert auto_store == ("daemon" if os.path.exists("/etc/NIXOS") else os.environ["NIXFILES_TEST_ROOT"])
    assert all("store with spaces" in args[args.index("--store") + 1] for args in calls[:-2])
    PY
    export PATH="$original_path"
    reject dotfiles-apply relative
    run dotfiles-diff "$target" >"$test_dir/before.diff"
    [[ -s "$test_dir/before.diff" && ! -e "$target/.config" ]]
    run dotfiles-apply "$target"
    run dotfiles-diff "$target" >"$test_dir/after.diff"
    [[ ! -s "$test_dir/after.diff" ]]
    [[ "$(readlink -f "$target/.config/git/config")" == "$checkout/src/dotfiles/git/config" ]]
    mv "$checkout" "$test_dir/checkout two"
    checkout="$test_dir/checkout two"
    run dotfiles-apply "$target"
    [[ "$(readlink -f "$target/.config/git/config")" == "$checkout/src/dotfiles/git/config" ]]
    printf 'Workflow dispatch, store selection, activation refusal, updates, and portable apply passed.\nReport: %s\n' "$test_dir"

# Build two tiny pinned fixtures and compare their closures without system activation
test-workflows-nix:
    #!/usr/bin/env bash
    set -euo pipefail
    umask 077
    test_dir=$(mktemp -d "${TMPDIR:-/tmp}/nixfiles-workflows-nix.XXXXXX")
    checkout="$test_dir/checkout with spaces"
    mkdir -p "$checkout"
    cp justfile "$checkout/justfile"
    jq '{version, root, nodes: {root: {inputs: {nixpkgs: .nodes[.root].inputs.nixpkgs}}, nixpkgs: .nodes.nixpkgs}}' flake.lock >"$checkout/flake.lock"
    nixpkgs_ref=$(jq -r '.nodes.nixpkgs.original | "github:\(.owner)/\(.repo)/\(.ref)"' flake.lock)
    printf '{ inputs.nixpkgs.url = "%s";\n' "$nixpkgs_ref" >"$checkout/flake.nix"
    cat >>"$checkout/flake.nix" <<'NIX'
      outputs = { nixpkgs, ... }: let
        pkgs = import nixpkgs { system = "x86_64-linux"; };
        version = builtins.readFile ./version;
      in {
        nixosConfigurations.probe.config = {
          networking.hostName = "probe";
          system.stateVersion = "24.11";
          warnings = [];
          system.build.toplevel = pkgs.writeText "workflow-probe-${version}" "fixture ${version}";
        };
      };
    }
    NIX
    printf 1 >"$checkout/version"
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git init -q --template= "$checkout"
    git -C "$checkout" add flake.nix flake.lock version
    lock_before=$(sha256sum "$checkout/flake.lock")
    run() { just --justfile "$checkout/justfile" "$@"; }
    [[ "$(run hosts)" == probe ]]
    run check-host probe >"$test_dir/check.json"
    jq -e '.hostName == "probe" and .warnings == [] and (.derivation | endswith(".drv"))' "$test_dir/check.json" >/dev/null
    run plan probe >"$test_dir/plan.log" 2>&1
    before=$(run build probe)
    printf 2 >"$checkout/version"
    run diff probe "$before" >"$test_dir/diff.log"
    after=$(run build probe)
    [[ "$before" != "$after" && "$before" == /nix/store/* && "$after" == /nix/store/* ]]
    [[ ! -e "$checkout/result" && "$(sha256sum "$checkout/flake.lock")" == "$lock_before" ]]
    grep -F 'workflow-probe: 1 → 2' "$test_dir/diff.log" >/dev/null
    printf 'Pinned fixture builds and closure diff passed; lock unchanged.\nReport: %s\n' "$test_dir"

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
    cp justfile "$checkout/justfile"
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
