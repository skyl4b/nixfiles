# Lint the embedded recipes and parse Nix without fetching inputs
check:
    #!/usr/bin/env bash
    set -euo pipefail
    for source in "$NIXFILES_CHECKOUT/justfile" "$NIXFILES_CHECKOUT"/src/scripts/*.just "$NIXFILES_CHECKOUT"/test/*.just; do
        just --justfile "$source" --fmt --check
    done
    just --dry-run _copy-justfiles /tmp/nixfiles-recipe-fixture 2>&1 | shellcheck -s bash -
    for recipe in baseline _syntax check test-doom test-doom-nix doom-install test-workflows test-workflows-nix test-portable-nix _test-portable hosts update-flatpak tailscale-up test-git test-git-nix test-terminals test-terminals-nix _test-tmux test-yazi-direnv test-yazi-direnv-nix _test-yazi-direnv test-starship-gitui test-starship-gitui-nix _test-starship-gitui test-cli-tools test-cli-tools-nix _test-cli-tools test-desktop-tools test-desktop-tools-nix _test-desktop-tools; do
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
    just --dry-run install-checkout moon skylab 2>&1 | shellcheck -s bash -
    just --dry-run _installer moon 2>&1 | shellcheck -s bash -
    just --dry-run test-install-workflows 2>&1 | shellcheck -s bash -
    just --dry-run remap-keyboard 'USB Keyboard' 2>&1 | shellcheck -s bash -
    just --dry-run doom sync 2>&1 | shellcheck -s bash -
    just --dry-run _doom run sync 2>&1 | shellcheck -s bash -
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
    just test-doom
    just test-install-workflows

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
