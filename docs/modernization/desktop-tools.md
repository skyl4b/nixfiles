# Native Zellij, Hyfetch, and Zathura configuration

These three application modules now use shared native files with live Home
Manager links and chezmoi adapters. The active settings were captured before
extraction to compare them with the native files.

| Canonical source | XDG target |
| --- | --- |
| `src/dotfiles/zellij/config.kdl` | `zellij/config.kdl` |
| `src/dotfiles/hyfetch/hyfetch.json` | `hyfetch.json` |
| `src/dotfiles/zathura/zathurarc` | `zathura/zathurarc` |

Zellij's KDL and Zathura's rc file are byte-identical to the former generated
files. Hyfetch's JSON retains every parsed setting. The large block of inactive
Zellij examples is removed from its Nix module; none became active settings.

## Packages and integrations

Zellij stays enabled in Home Manager with empty generated settings. This keeps
its package, Bash auto-start integration, and the existing
`ZELLIJ_AUTO_ATTACH=false` and `ZELLIJ_AUTO_EXIT=false` environment variables.
The native KDL starts in locked mode, binds Ctrl-Space to normal mode, and hides
startup tips and release notes. Other bindings retain Zellij's defaults.

Hyfetch stays enabled for package installation. Its native JSON keeps the
neofetch backend, rainbow preset, RGB mode, lightness, color alignment, and
existing `pride_month_disable` value. The package includes the neowofetch backend.

The pinned Home Manager Zathura module always generates a `zathurarc`, even when
its settings are empty. The native module installs `programs.zathura.package`
directly, preserving the package override and bundled viewer plugins. Its rc
file keeps highlight transparency at 0.05, the clipboard selection target, and
Ctrl-D/Ctrl-U bindings for next/previous page.

All three files use the shared `dotfiles.anchor`; refresh it after moving the
checkout. Chezmoi links to the same sources relative to its source directory.
Reapply chezmoi with the new source path after a move. No checkout path is
hardcoded, and no custom assertion guards are added.

On non-NixOS systems, install the applications through the destination operating
system. Chezmoi deploys only files; shell integration must be configured there.
To reproduce the existing Zellij Bash auto-start behavior, use Zellij's generated
shell integration in that shell's startup configuration.

## Verification

```sh
pixi run --locked check
NIXFILES_TEST_ROOT=/absolute/path/to/writable/scratch pixi run --locked test-desktop-tools-nix
NIXFILES_TEST_ROOT=/absolute/path/to/writable/scratch pixi run --locked baseline
```

`check` includes `test-desktop-tools`: it applies chezmoi into a temporary home,
verifies links, parses JSON, edits the live KDL file, and relocates its checkout.
KDL and rc semantics are checked by the pinned applications in the Nix test.

`test-desktop-tools-nix` builds the isolated Home Manager file tree, checks Bash
integration and session variables, and moves the checkout before starting the
applications. Both checkout and XDG paths contain spaces. Development tools and
Python terminal-test libraries remain in Pixi. Nix supplies application binaries
and the private display tools used for actual runtime checks.

Zellij runs with a private socket directory and a test-only Bash pane, without
reading shell startup files. Its test checks initial locked mode, Ctrl-Space
unlocking, and quitting through the normal bindings. The test explicitly disables
its web server and session serialization; these are test options, not changes to
the native configuration.

Hyfetch renders a temporary ASCII logo through its bundled neowofetch backend.
The test checks that editing the native preset changes the rendered colors.
Neowofetch's own configuration is disabled for the test, and the existing
`pride_month_disable` setting stays enabled to avoid its seasonal animation.

Zathura opens a temporary two-page PDF on a private Xvfb display and D-Bus session.
Real key events exercise both page bindings and an edited binding after restart.
A test-only setting exposes the current page in the window title. This checks
viewer behavior without opening a window on the current desktop. Real display,
clipboard, font, and document-workflow behavior still need target-machine checks.

Test configurations, logs, sessions, viewer state, and the PDF fixture remain in
temporary directories. No Home Manager activation or deployment is performed.

The shared `src/tests/flake-inputs.nix` loader reads the Git-filtered checkout and
encodes its path for URI use. This keeps ignored Pixi environments and scratch
data out of the test store, including when checkout paths contain spaces.
The previous unfiltered loader copied the environment on each changed snapshot;
those redundant test snapshots were removed through Nix's store management.

Validated on 2026-10-19: `check` passed with all 42 Nix source files parsed and
the portable deployment checks. The combined Home Manager/runtime test passed
with Zellij 0.43.1, Hyfetch 2.0.4, and Zathura 0.5.13. Its temporary report is at
`/tmp/nixfiles-desktop-tools-nix.PZjYQZ/`.

All 16 host baseline checks passed; the full report is at
`/tmp/nixfiles-baseline.bnaE3I/summary.md`. Package versions and counts, session
settings, warning content, and state versions are preserved. Direct Zathura
installation changes package ordering and the resulting home-profile store path;
the generated fontconfig file differs only in that derived path. The other
changed file entries are the three native links. Nix input pins are unchanged;
the lockfile SHA-256 remains
`a9eb0728ead343cc10dee5a55a0ce538f40220fe4115ac641adc42f1bb9fd8dc`.
