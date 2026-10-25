# Complete portable rehearsal (NIX-19)

The complete chezmoi deployment now has one repeatable application rehearsal:

```sh
pixi run --locked test-portable-nix
```

It runs on the current non-NixOS system in an isolated temporary home. Chezmoi
and orchestration tools come from Pixi; the actual application binaries come
from the existing pinned Nix test fixtures. No Home Manager generation is built
or activated for this rehearsal.

## What is covered

The recipe copies only native files, chezmoi adapters, and the justfile into a
temporary checkout. It invokes the public `dotfiles-diff` and `dotfiles-apply`
recipes, starting with an empty destination. It then:

1. Confirms preview installs no config, application succeeds, and the next diff
   is empty.
2. Compares every deployed symlink with `dotfiles.configFiles` evaluated from the
   same Home Manager module list used by the repository. All 26 native targets
   have exactly one owner and resolve into the temporary checkout.
3. Confirms there is no Home Manager nix-direnv loader or Nix-supplied tmux plugin
   tree, and that native files contain no Nix store or fixed user-home paths.
4. Moves the checkout between paths containing spaces, reapplies from its new
   location, and verifies the complete link tree again.
5. Runs eight application groups against that single chezmoi-owned config tree,
   with separate temporary caches, private sockets/displays, and test projects.
6. Checks the final chezmoi diff and all link destinations after live-edit tests.

The Nix fixture reuses the existing application runtime fixtures. They supply
binaries for actual tests; their Home Manager file-tree outputs are not used.
Commitlint additionally exercises the native JavaScript config, accepting a
conventional message and rejecting an invalid fixture.

Direnv's shared runtime check now tests whichever deployment is supplied. With
Home Manager's loader present, it verifies nix-direnv as before. With the portable
chezmoi tree, it verifies ordinary authorization, strict mode, live stdlib edits,
and project-specific cache directories without that loader. Portable tmux runs
its base configuration without assuming Nix-installed plugins.

## Results

Validated on 2026-10-20 in Ubuntu 24.04.5 LTS (the current distrobox):

| Group | Result |
| --- | --- |
| Full file map, idempotence, and relocation | PASS: 26 targets |
| Git config and origins | PASS |
| Commitlint native config and valid/invalid messages | PASS |
| tmux base config, bindings, and live reload | PASS |
| WezTerm config loader | PASS |
| Yazi navigation/plugin/editor/theme and portable direnv | PASS |
| Starship prompt and interactive Gitui | PASS |
| Bat/cache, bottom, ripgrep, tealdeer | PASS |
| Zellij, Hyfetch, Zathura | PASS |

The report is `/tmp/nixfiles-portable.VAFj3R/summary.md`, with per-group logs,
chezmoi diffs, OS information, metadata, and link checks in the same directory.
The earlier seven-group run is `/tmp/nixfiles-portable.ySvAbC/summary.md`.
The final run also gives every application private XDG state and an empty working
directory; application checks do not depend on the repository as their cwd.
Recipe lint, syntax parsing of all 46 Nix files, and the existing portable checks
also pass. The added fixture lives under `src/tests/`; scripts remain in the
justfile and test state stays under temporary directories or ignored `.pixi/`.

No input, native config, system/home package selection, state version, hardware,
or host policy changed in this phase. The lockfile SHA-256 remains
`1f7f865907cf033fcac11bb27610c9e5de064a7d20f9d88e48e51cac955cb9cc`.
The [input refresh](input-refresh.md) records the preceding host baseline and
pinned application validation.

## Limits and remaining gates

This tests a temporary home inside an existing Ubuntu container. It does not
claim a newly provisioned OS/user account, distro-package installation, another
architecture, or a fresh-machine bootstrap. Applications are pinned Nix builds;
the portable files themselves do not depend on their store paths. Runtime
settings supplied by the test harness are not installed shell startup files.

See the [maintenance guide](../maintenance.md) for required portable shell
integration, ripgrep's config variable, bat cache initialization, optional tmux
plugins, and the difference between Home Manager and chezmoi ownership.
Installation into a real home and testing its existing-file conflicts remain
part of actual deployment. NIX-20's complete host builds, target-machine tests,
activation/recovery checks, and NIX-21's fresh-machine onboarding acceptance
remain pending. Moon still requires its own supplied hardware/deployment details.
