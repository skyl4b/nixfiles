# Install Doom's writable checkout using the already deployed personal config
doom-install:
    just _doom install

# Run Doom maintenance commands, e.g. `just doom sync` or `just doom doctor`
[positional-arguments]
doom +args:
    #!/usr/bin/env bash
    set -euo pipefail
    just _doom run "$@"

[positional-arguments]
_doom action *args:
    #!/usr/bin/env bash
    set -euo pipefail
    action="$1"
    shift
    case "$action" in install|run) ;; *) exit 2 ;; esac
    config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    # Emacs checks the legacy directory before its XDG location.
    if [[ -z "${EMACSDIR:-}" ]]; then
        if [[ "$action" == install ]]; then
            for file in "$HOME/.emacs" "$HOME/.emacs.el" "$HOME/.emacs.elc"; do
                [[ ! -e "$file" && ! -L "$file" ]] || {
                    printf '%s takes precedence over the Doom checkout. Review it before installing Doom.\n' "$file" >&2
                    exit 2
                }
            done
        fi
        if [[ -e "$HOME/.emacs.d" || -L "$HOME/.emacs.d" ]]; then
            EMACSDIR="$HOME/.emacs.d"
        else
            EMACSDIR="$config_home/emacs"
        fi
    fi
    if [[ -z "${DOOMDIR:-}" ]]; then
        if [[ ! -d "$config_home/doom" && -d "$HOME/.doom.d" ]]; then
            DOOMDIR="$HOME/.doom.d"
        else
            DOOMDIR="$config_home/doom"
        fi
    fi
    export EMACSDIR DOOMDIR
    if [[ "$action" == install ]]; then
        if [[ -z "${EMACS:-}" ]] && ! command -v emacs >/dev/null; then
            printf 'Install Emacs first (on NixOS, apply the user profile with just switch).\n' >&2
            exit 127
        fi
        for file in init.el config.el packages.el; do
            [[ -f "$DOOMDIR/$file" ]] || {
                printf 'Deploy your Doom files first; missing %s/%s.\n' "$DOOMDIR" "$file" >&2
                exit 2
            }
        done
        if [[ ! -e "$EMACSDIR" && ! -L "$EMACSDIR" ]]; then
            mkdir -p -- "$(dirname -- "$EMACSDIR")"
            git clone --depth 1 -- https://github.com/doomemacs/core "$EMACSDIR"
        fi
    fi
    [[ -x "$EMACSDIR/bin/doom" ]] || {
        printf 'No Doom executable at %s/bin/doom. Existing directories are left untouched.\n' "$EMACSDIR" >&2
        printf 'Use just doom-install for a new installation.\n' >&2
        exit 2
    }
    if [[ "$action" == install ]]; then
        exec "$EMACSDIR/bin/doom" install --no-config "$@"
    fi
    exec "$EMACSDIR/bin/doom" "$@"
