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
