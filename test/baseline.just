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
