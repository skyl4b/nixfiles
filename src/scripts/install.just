# ERASE, format, and mount a host's configured disks using its pinned Disko script
[positional-arguments]
disko host:
    #!/usr/bin/env bash
    set -euo pipefail
    just _installer "$1"
    config=".#nixosConfigurations.$1.config"
    disks=$(just _nix eval --no-update-lock-file --raw "$config.disko.devices.disk" \
        --apply 'disks: builtins.concatStringsSep "\n" (map (disk: disk.device) (builtins.attrValues disks))')
    script=$(just _nix build --no-update-lock-file --no-link --print-out-paths \
        --max-jobs 1 --cores 2 "$config.system.build.diskoScript")
    printf 'ERASE, format, and mount the configured disks for %s:\n%s\n' "$1" "$disks" >&2
    reply=""
    read -r -p 'Do you want to proceed? [y/N] ' reply || reply=""
    case "$reply" in
        [yY]|[yY][eE][sS]) ;;
        *) printf 'Disko cancelled; no disks changed.\n' >&2; exit 1 ;;
    esac
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

# Copy this working tree and Git history into an installed user's home and link dotfiles
[positional-arguments]
install-checkout host user root="/mnt" destination="":
    #!/usr/bin/env bash
    set -euo pipefail
    just _installer "$1"
    [[ "$2" =~ ^[a-z_][a-z0-9_-]*$ && "$3" == /* ]] || { printf 'Supply a user name and absolute target root.\n' >&2; exit 2; }
    root=$(realpath -e -- "$3")
    mountpoint -q -- "$root" || { printf 'Target root is not mounted: %s\n' "$root" >&2; exit 2; }
    [[ -d "$NIXFILES_CHECKOUT/.git" && ! -L "$NIXFILES_CHECKOUT/.git" ]] || {
        printf 'Use a regular Git clone for installation, rather than a linked worktree.\n' >&2; exit 2
    }
    metadata=$(just _nix eval --no-update-lock-file --json ".#nixosConfigurations.$1.config" \
        --apply "config: { home = config.users.users.\"$2\".home; anchor = config.home-manager.users.\"$2\".dotfiles.anchor; }")
    home=$(jq -er '.home' <<< "$metadata")
    anchor=$(jq -er '.anchor' <<< "$metadata")
    account=$(awk -F: -v name="$2" '$1 == name { print $3 ":" $4 ":" $6; found=1; exit } END { if (!found) exit 1 }' "$root/etc/passwd") || {
        printf 'Install NixOS first; the selected user is missing from the target.\n' >&2; exit 2
    }
    IFS=: read -r uid gid installed_home <<< "$account"
    [[ "$home" == "$installed_home" ]] || { printf 'The installed home does not match the selected configuration.\n' >&2; exit 2; }
    destination="${4:-$home/Projects/nixfiles}"
    [[ "$destination" == /* && "$anchor" == /* && "$uid" =~ ^[0-9]+$ && "$gid" =~ ^[0-9]+$ ]] || exit 2
    destination=$(realpath -ms -- "$destination")
    anchor=$(realpath -ms -- "$anchor")
    [[ "$destination" != / && "$anchor" != / ]] || exit 2
    temporary=$(mktemp -d "${TMPDIR:-/tmp}/nixfiles-install-checkout.XXXXXX")
    trap 'rm -rf -- "$temporary"' EXIT
    git -C "$NIXFILES_CHECKOUT" ls-files --cached --others --exclude-standard -z > "$temporary/files"
    printf '.git\0' > "$temporary/archive-files"
    while IFS= read -r -d '' file; do
        [[ -f "$NIXFILES_CHECKOUT/$file" || -L "$NIXFILES_CHECKOUT/$file" ]] || continue
        printf '%s\0' "$file" >> "$temporary/archive-files"
    done < "$temporary/files"
    tar --create --file "$temporary/checkout.tar" --directory "$NIXFILES_CHECKOUT" \
        --null --verbatim-files-from --files-from "$temporary/archive-files"
    sudo bash -s -- "$root" "$destination" "$anchor" "$uid" "$gid" "$temporary/checkout.tar" <<'SH'
    set -euo pipefail
    root="$1" logical_destination="$2" logical_anchor="$3" uid="$4" gid="$5" archive="$6"
    destination="${root%/}$logical_destination"
    anchor="${root%/}$logical_anchor"
    # Absolute symlinks in a mounted target would otherwise resolve on the live host.
    for target in "$destination" "$anchor"; do
        parent=$(dirname -- "$target")
        while [[ "$parent" != "$root" && "$parent" != / ]]; do
            [[ ! -L "$parent" ]] || { printf 'Refusing a symlinked target parent: %s\n' "$parent" >&2; exit 2; }
            parent=$(dirname -- "$parent")
        done
    done
    [[ ! -e "$destination" && ! -L "$destination" ]] || { printf 'Checkout already exists: %s\n' "$destination" >&2; exit 2; }
    [[ ! -e "$anchor" || -L "$anchor" ]] || { printf 'Refusing to replace a non-symlink anchor: %s\n' "$anchor" >&2; exit 2; }
    make_parent() {
        [[ ! -d "$1" ]] || return 0
        make_parent "$(dirname -- "$1")"
        install -d -m 0755 -o "$uid" -g "$gid" -- "$1"
    }
    make_parent "$(dirname -- "$destination")"
    make_parent "$(dirname -- "$anchor")"
    staging=$(mktemp -d "$(dirname -- "$destination")/.nixfiles.XXXXXX")
    trap 'rm -rf -- "$staging"' EXIT
    tar --extract --no-same-owner --file "$archive" --directory "$staging"
    chmod 0755 "$staging"
    chown -hR -- "$uid:$gid" "$staging"
    mv -T -- "$staging" "$destination"
    ln -sfnT -- "$logical_destination" "$anchor"
    chown -h -- "$uid:$gid" "$anchor"
    printf 'Checkout: %s\nDotfile anchor: %s -> %s\n' "$logical_destination" "$logical_anchor" "$logical_destination"
    SH

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
