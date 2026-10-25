# Optional virtualization services

Virtualization is selected by each host's imports under
`src/modules/nixos/virtualisation/`. The shared workstation module no longer
enables container engines or virtual machines.

| Host | Docker | Podman | libvirt and virt-manager | Waydroid |
| --- | --- | --- | --- | --- |
| Jupiter | Yes | No | Yes | No |
| Mars | Yes | Yes | Yes | No |
| Moon | Yes | Yes | No | Yes |

Jupiter and Mars retain their existing service selections. Moon uses Docker,
Podman, and Waydroid as requested. Its complete home application profile remains
unchanged; that profile does not select system virtualization services.

## Container engines and account access

The Docker module enables the existing rootful daemon and CLI. The Podman module
enables Podman and DNS for its default network, matching Mars's previous setup.
Podman's Docker command alias and replacement Docker socket remain disabled, so
the two engines keep their own commands and sockets. No extra Podman privileged
group membership is granted for normal rootless CLI use.

The shared Skylab user declaration now derives Docker and libvirt group
memberships from the selected services. Jupiter and Mars retain their previous
groups. Moon keeps `docker` and drops `kvm` and `libvirtd` because it does not
enable the virtual-machine module.

## Waydroid on Moon

The standard NixOS Waydroid module supplies its package, LXC integration,
container service, Binder kernel requirements, and `psi=1` kernel parameter.
The selected package is `pkgs.waydroid-nftables`: the pinned Waydroid networking
script otherwise prefers legacy iptables, which is unsuitable for the current
kernel. This package choice does not switch the host's firewall backend.
See the [upstream compatibility discussion](https://github.com/NixOS/nixpkgs/pull/466473).

The upstream module trusts the internal `waydroid0` interface. Podman's module
permits UDP 53 only on `podman0` for its DNS service. No physical interface is
added to the trusted list, and no new global TCP or UDP port is opened here.
Docker, Podman, and Waydroid also manage runtime networking rules, so input
firewall observations alone do not establish working forwarding.

Android image initialization and image selection remain deployment steps; no
image downloads or user-session startup are automated here. On Moon, test
Waydroid in GNOME's Wayland session, including graphics, touch, networking,
suspend, and coexistence with both container engines. Check networking after
engine restarts as well as after boot
([Waydroid networking guidance](https://docs.waydro.id/debugging/networking-issues)).

Repository checks and evaluated build plans do not replace those target tests.

## Repository verification

Repository checks pass, including recipe lint, parsing all 54 Nix files,
portable component checks, and workflow tests
(`/tmp/nixfiles-virtualization-check.log`). Focused evaluation records the
before/after configurations in `/tmp/nixfiles-virtualization-before.json` and
`/tmp/nixfiles-virtualization-after.json`. The comparison log is
`/tmp/nixfiles-virtualization-comparison.log`.

Jupiter and Mars retain their exact system derivations, service settings,
account groups, firewall observations, kernel settings, and package selections.
Moon's complete home package list is unchanged. Its requested services,
service-dependent groups, internal-interface firewall contributions, kernel
parameter, and Waydroid service definition evaluate as intended. All three host
warning lists are empty. No complete system build or activation was performed.

All 26 baseline checks pass, including the three host build plans, Hyprland
evaluation, and flake check (`/tmp/nixfiles-baseline.huSWaD/summary.md`). The
selected Waydroid package declares `USE_NFTABLES=1`
(`/tmp/nixfiles-virtualization-waydroid-flags.json`). The lockfile is unchanged.
