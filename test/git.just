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
    just _copy-justfiles "$checkout"
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
    just _copy-justfiles "$checkout"
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
