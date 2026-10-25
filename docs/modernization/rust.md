# No global Rust toolchain

At the user's request, `rust-overlay` and the global Rust toolchain are removed.
No rustup, compiler, Cargo, formatter, analyzer, source component, or target
bundle is installed as a replacement. Individual projects should supply the
Rust tooling they need.

The flake has four direct inputs and seven lock nodes, with one nixpkgs node.
Only the agenix overlay remains. All retained direct input revisions and state
versions are unchanged. This repository has no Rust sources and gains no Rust
development dependency; its development tools remain in Pixi.

Dioxus, wasm-bindgen, and the existing LLVM linker package remain for the broader
development-package audit. Removing the global toolchain does not remove Rust
libraries or build dependencies used internally by other Nix packages.

The subsequent [package split](packages.md) removes those remaining framework
and linker entries from the global home profile too.

## Verification

Both host evaluations and build plans are compared with the preceding input
audit. The expected changes are removal of the Rust home-package entry and
fontconfig's reference to the resulting home package profile. Hardware,
services, firewall/cache policy, other package paths/order, and state versions
remain unchanged.

No commands modified the current user's Rust/Cargo directories or toolchain
defaults. No replacement toolchain was installed.

The before/after comparison confirms that both hosts have 138 declared home
packages, with no global Rust toolchain or rustup entry. Only the former Rust
package and the generated fontconfig profile reference change from the input
audit baseline. All other package paths/order, home files/session settings,
hardware, services, and policy match. The comparison report is
`/tmp/nixfiles-no-global-rust-comparison.json`.

Validated on 2026-10-19: all 44 Nix sources parsed and all 19 baseline checks
passed, including both host derivations/build plans and flake check. Both hosts
retain empty warning lists. The report is
`/tmp/nixfiles-baseline.ChTPzy/summary.md`. No complete system build or activation
was performed.

The lockfile SHA-256 remains
`0feb9b270b85054351b6a1ca0818054fcef6ed251a3e89624d9bb44470d7ee69`.
