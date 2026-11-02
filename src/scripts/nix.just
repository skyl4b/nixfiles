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

# Activate and set the boot default (defaults to this machine's hostname)
[positional-arguments]
switch host=`hostname`:
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
    nix_cmd=(nix --extra-experimental-features 'nix-command flakes')
    case "$store" in
        # NixOS already defaults to the system daemon. An explicit store setting
        # is forwarded to the daemon and warns for ordinary, untrusted users.
        daemon) ;;
        /*)
            mkdir -p -- "$store/cache"
            export XDG_CACHE_HOME="$store/cache"
            nix_cmd+=(--store "$store" --option build-users-group '')
            ;;
        *) printf 'NIXFILES_STORE must be auto, daemon, or an absolute writable store root.\n' >&2; exit 2 ;;
    esac
    exec "${nix_cmd[@]}" "$@"

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
    command -v jq >/dev/null || { printf 'jq is required for host selection. Enter a Nix shell with just and jq before rebuilding.\n' >&2; exit 127; }
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
