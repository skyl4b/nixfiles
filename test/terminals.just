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
    just _copy-justfiles "$checkout"
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
