# Test workflow dispatch with stub Nix commands and real temporary chezmoi homes
test-workflows:
    #!/usr/bin/env bash
    set -euo pipefail
    umask 077
    test_dir=$(mktemp -d "${TMPDIR:-/tmp}/nixfiles-workflows.XXXXXX")
    checkout="$test_dir/checkout one"
    target="$test_dir/home one"
    mkdir -p "$checkout/src" "$target" "$test_dir/bin"
    just _copy-justfiles "$checkout"
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
        reject switch
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
    assert "--store" not in calls[-1]
    assert "build-users-group" not in calls[-1]
    if os.path.exists("/etc/NIXOS"):
        assert "--store" not in calls[-2]
    else:
        assert calls[-2][calls[-2].index("--store") + 1] == os.environ["NIXFILES_TEST_ROOT"]
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
    just _copy-justfiles "$checkout"
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
