# Home tools and project toolchains (NIX-17)

Home Manager retains everyday applications and shared editor helpers. Compilers,
language runtimes, notebook environments, and framework build tools are removed
from the default home profile so projects can select their own dependencies.
The user explicitly chose to keep language servers and formatters global.

`src/home/skylab.nix` now contains the user composition, compatibility version,
session preferences, and desktop theme. Its explicit `home.packages` assignment
imports the package list from `src/home/packages.nix`. This is a plain list
import, preserving the precedence of existing package definitions. There is no
recursive package discovery or additional profile toggle.

## What stays global

- Everyday CLI tools, fonts, file/viewer tools, terminal integrations, and
  application configurations retain their previous package selections.
- Neovim and Emacs remain the chosen editors. VS Code and Zed are removed from
  the home profile, following the user's earlier editor choice.
- Existing language servers, linters, and formatters remain, including Python,
  shell, web, C/C++, Nix, Markdown, Lua, XML, CMake, LaTeX, and Typst helpers.
  No Rust toolchain or replacement Rust helpers are introduced.
- Quarto stays as a publishing frontend with its existing Python/R overrides
  disabled; a publishing project supplies its own engines. Gnuplot, spell
  checking, and other general authoring tools remain.
- Just, commitlint, and devcontainer remain as shared task/lint/container
  clients. Their presence does not replace project dependency declarations.

Six legacy `nodePackages` aliases for editor helpers now use their canonical
top-level attributes. Their evaluated package store paths are unchanged.

## What projects now supply

| Area | Removed global entries |
| --- | --- |
| C/C++ builds and debugging | Priority GCC, Clang compiler, GDB, LLDB, LLVM binutils, GNU Make |
| Python notebooks | The priority Jupyter environment and its bundled jupyter-console, jupytext, nbclient, debugpy, editorconfig, grip, and Python Catppuccin dependencies |
| JavaScript/TypeScript runtimes and builds | Node.js, Deno, Bun, standalone TypeScript compiler |
| Gleam/Erlang projects | Gleam, Erlang, rebar3 |
| Rust/web framework tooling | Dioxus CLI, wasm-bindgen CLI; the global Rust toolchain was already removed |
| Parser development | Tree-sitter CLI; Neovim's internal parser support remains |

Language servers and applications may still carry private runtime/compiler
dependencies. Removing a global package entry does not eliminate those internal
dependencies or promise that every executable is absent from all Nix closures.

No hypothetical Rust, Python, or web project environments are added to this
configuration repository. Each actual project should declare and pin its own
tools. In this repository, Pixi remains the source of development dependencies;
its manifest and lockfile need no change for this split. No repository Nix
devShell is introduced. Native dotfiles and their chezmoi/Home Manager ownership
remain unchanged.

## Neovim providers

The previous `neovim-unwrapped.override { nodejs = true; python3 = true; }`
did not configure runtime providers: those arguments belong to the pinned
unwrapped package's build-test inputs. It is replaced by the pinned Neovim
wrapper with `withNodeJs` and `withPython3` enabled. The wrapper selects private
provider hosts and appends its runtime fallback to Neovim's PATH, preserving
project runtime precedence. It keeps normal user configuration loading.

The relevant behavior was checked in the pinned
[unwrapped package](https://github.com/NixOS/nixpkgs/blob/89c2b2330e733d6cdb5eae7b899326930c2c0648/pkgs/by-name/ne/neovim-unwrapped/package.nix),
[wrapper](https://github.com/NixOS/nixpkgs/blob/89c2b2330e733d6cdb5eae7b899326930c2c0648/pkgs/applications/editors/neovim/wrapper.nix),
and [wrapper configuration helper](https://github.com/NixOS/nixpkgs/blob/89c2b2330e733d6cdb5eae7b899326930c2c0648/pkgs/applications/editors/neovim/utils.nix).
The existing system Neovim fallback is unchanged.

## Validation

```sh
pixi run --locked just _syntax
NIXFILES_TEST_ROOT=/absolute/path/to/writable/scratch pixi run --locked baseline
```

The headless test builds the actual selected home Neovim package. In temporary
XDG directories it verifies user configuration loading, Python evaluation, Node
RPC, and a project-provided Node executable taking precedence over the wrapper
fallback. The test report is `/tmp/nixfiles-editor.Gz1yY9/`.

Input pins, state versions, system packages, services, firewall/cache policy,
and native files stay fixed. Only the intended home-package removals, Neovim
wrapper replacement, and resulting generated profile references should change.
No system or user profile is activated, and no project environment is installed.

Validated on 2026-10-19: syntax checks parsed all 45 Nix sources, and all 19
baseline checks passed, including both host derivations/build plans, Hyprland
evaluation, and flake check. Both hosts retain empty warning lists. The report
is `/tmp/nixfiles-baseline.HR34oa/summary.md`.

Each host's declared home-package count drops from 138 to 119. The exact
comparison confirms the intended 19 net removals, Neovim wrapper replacement,
and unchanged paths/order for retained packages. All system package paths and
policy match the preceding baseline. The only changed home-file entry is
fontconfig's reference to the changed home package profile; its other content
matches. The comparison report is `/tmp/nixfiles-packages-comparison.json`,
with pre-change sources/policy under `/tmp/nixfiles-packages-before/`.

The lockfile SHA-256 remains
`0feb9b270b85054351b6a1ca0818054fcef6ed251a3e89624d9bb44470d7ee69`.
These evaluations and the editor smoke test do not constitute complete system
builds or a deployed editor session.
