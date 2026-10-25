# Input and cache audit (NIX-16)

The input graph now has five direct inputs and one nixpkgs node. This pass
changes dependency wiring and cache scope without refreshing retained revisions.
The lockfile shrinks from 11 to 8 nodes, including its root node.

The subsequent user-requested [Rust overlay removal](rust.md) reduces this to
four direct inputs and seven nodes, removing the global Rust toolchain entirely.
The inventory and unchanged-package comparison below
record the initial input-audit step before that follow-up.

| Direct input | Consumer and reason to retain it |
| --- | --- |
| nixpkgs | NixOS, Home Manager packages, test fixtures, and the COSMIC desktop packages |
| home-manager | Integrated home modules and isolated file/runtime tests; follows the root nixpkgs |
| nixos-hardware | Explicit CPU/GPU/laptop/System76 modules for the reference hosts |
| agenix | The existing home CLI package through the agenix overlay; follows root nixpkgs and Home Manager |
| rust-overlay | The configured Rust toolchain; its nixpkgs input now follows the root nixpkgs |

The retained root pins remain:

```text
nixpkgs       89c2b2330e733d6cdb5eae7b899326930c2c0648
home-manager  d10a9b16b2a3ee28433f3d1c603f4e9f1fecb8e1
nixos-hardware 899dc449bc6428b9ee6b3b8f771ca2b0ef945ab9
agenix        fcdea223397448d35d9b31f798479227e80183f6
rust-overlay  7f3aa46dfa230ec2a4ca9281186a24771650ccd1
```

Agenix's Darwin and systems dependencies remain transitive lock nodes: upstream
uses them for platform outputs and checks. Their presence does not enable Darwin
configuration here. No secret-deployment module is enabled by installing its CLI.

## Removed input and consolidated graph

The Catppuccin flake had become unused after the native-file migrations. Its
global theming and cache were disabled, and no application module referenced its
options anymore. Its input and NixOS/Home Manager imports are removed, including
the two remaining isolated test imports. Native themes, their licenses, the
nixpkgs tmux plugin, and the Jupyter Python theme package are unchanged.

This also removes Catppuccin's separate nixpkgs node, which had the same revision
and content hash as the root. Rust's private nixpkgs node is replaced by a
`follows` edge. The applied Rust overlay still builds against the host package
set, as before. This simplifies the lock graph; it is not a claim that the host
previously built its Rust toolchain against that private node.

The [Nix manual](https://nix.dev/manual/nix/2.35/command-ref/new-cli/nix3-flake.html#flake-inputs)
documents input following and notes that modules/overlays commonly use the
consumer's package set already. Home Manager's `useGlobalPkgs` and the two
explicit overlays stay in place. No replacement input or repository devShell
was introduced; repository development dependencies remain in Pixi.

## Cache scope

The default NixOS cache now comes from NixOS's upstream default rather than an
additional identical shared entry. The COSMIC cache import moves from the shared
Nix module to the COSMIC desktop module.

| Host | Effective cache URLs | Trusted keys |
| --- | --- | --- |
| Jupiter, GNOME | `https://cache.nixos.org/` | NixOS cache key |
| Mars, COSMIC | `https://cosmic.cachix.org/`, `https://cache.nixos.org/` | Existing COSMIC and NixOS keys |

Jupiter no longer trusts the unused COSMIC cache. Mars keeps the same two cache
identities and keys, with the redundant NixOS URL removed. No new key is added.
Signature verification, sandboxing, trusted users, firewall rules, and service
choices remain unchanged. Helix's cache was removed in an earlier phase;
Catppuccin's cache was never enabled in the audited configuration.

## Validation and later version updates

```sh
pixi run --locked check
NIXFILES_TEST_ROOT=/absolute/path/to/writable/scratch pixi run --locked baseline
NIXFILES_TEST_ROOT=/absolute/path/to/writable/scratch pixi run --locked test-yazi-direnv-nix
NIXFILES_TEST_ROOT=/absolute/path/to/writable/scratch pixi run --locked test-starship-gitui-nix
```

The lock graph was regenerated from cached sources. Each retained direct input's
entire locked identity was compared with the pre-change lockfile, rather than
comparing node labels, which Nix can rename. State versions stay fixed.

Validated on 2026-10-19: the portable check suite passed with all 44 Nix sources
parsed. All 19 baseline checks passed; the report is
`/tmp/nixfiles-baseline.Hlf3A0/summary.md`. Both hosts report no warnings.
The affected Yazi/direnv and Starship/gitui Nix runtime suites also passed,
including built Home Manager links, shell hooks, checkout relocation, and
application behavior. Their reports are `/tmp/nixfiles-yazi-direnv-nix.WdJVK4/`
and `/tmp/nixfiles-starship-gitui-nix.6N4xYr/`. The Yazi fixture's temporary home
with spaces still emits the pinned Home Manager Zsh history-path warning; that
warning is absent from the reference hosts.

Compared with the preceding policy baseline, both hosts retain identical
hardware, accounts, services, firewall rules, session values, home-file
definitions, and exact system/home package paths and ordering. Only the cache
URL/key differences above remain. Reports are `/tmp/nixfiles-input-graph.json`
and `/tmp/nixfiles-input-comparison.json`; pre-change inputs and policy logs are
saved under `/tmp/nixfiles-input-before/`.

The new lockfile SHA-256 is
`c702e8b1a1586a894858d9281aa30f4cc4a77e26cafef7bf584d6db61f0cab39`.
Its content changes because of graph pruning and following, not a retained
direct input revision update. No complete system build or activation was run.

Version refreshes remain a separate step: select a small input group, inspect
the lock diff and relevant release notes, rerun host checks, and compare the
resulting behavior/package changes before accepting the refresh. Nixpkgs and
Home Manager may need a coordinated update. No deployment or version refresh
was performed in this audit. The legacy all-input update recipe will be replaced
in the separate workflow phase before it is used for this process.

The subsequent [workflow phase](workflows.md) supplies the selected-input updater.
The [controlled refresh](input-refresh.md) records the later retained-input
version updates and the current five-node graph. The pins and counts above
remain the historical record of this wiring-only audit.
