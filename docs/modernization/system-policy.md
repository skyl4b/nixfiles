# Firewall and service policy (NIX-15)

The shared workstation configuration now enables the NixOS firewall by default.
Service modules supply the exceptions below. Existing service choices remain:
Jupiter uses GNOME discovery; Mars also uses KDE Connect, Tailscale, and Podman.
This policy is prepared for future deployment; nothing was activated here.

The later [virtualization split](virtualisation.md) preserves Jupiter and Mars's
choices and gives Moon Docker, Podman, and Waydroid without libvirt. It records
Moon's additional internal-interface rules and service-dependent account groups.
The historical two-host audit below predates that change and the GNOME cleanup.

## Inbound exceptions

| Host | Traffic | Owner and purpose |
| --- | --- | --- |
| Both | UDP 5353 | Avahi mDNS discovery; GNOME enables Avahi on Jupiter, Mars enables it explicitly |
| Mars | TCP and UDP 1714–1764 | The enabled KDE Connect module supplies its required ranges |
| Mars | UDP 41641 | Tailscale's configured transport port, opened through `services.tailscale.openFirewall` |
| Mars, `podman0` only | UDP 53 | The Podman module permits containers to reach its configured DNS service |

These are the NixOS host-input exceptions, not an inventory of runtime NAT,
container, VM, or Tailscale-managed rules. The upstream firewall also permits
loopback, replies to established/related connections, ICMP, and DHCPv6 client
traffic. Neither the physical interfaces nor `tailscale0` are added as blanket
trusted interfaces by this configuration. Reverse-path checking remains enabled;
the existing iptables backend and forwarding policy remain in place.

KDE Connect is enabled only on Mars. Jupiter selects the GSConnect package in
its desktop module but does not enable `programs.kdeconnect`, so no phone-sharing
port range is opened there. No extra ports were added for optional applications
such as remote desktop or wireless display software.

## Discovery and remote access

Avahi's firewall exception is explicit in the shared module; reflecting mDNS
between networks stays disabled. Jupiter keeps publishing disabled. Mars keeps
user-service publishing enabled, including the resulting address publication.
The existing interface selection and wide-area discovery defaults are retained.
No physical interface names or LAN subnet ranges were guessed. Restricting
discovery to specific trusted networks requires the eventual machine's network
details.

Mars keeps Tailscale in endpoint mode, without subnet-router/exit-node settings,
automatic enrollment, or new SSH flags. Its UDP exception supports direct peer
connections; it is not an SSH opening or a blanket tailnet trust rule. Tailscale
can use relay connections without this exception. Tailnet grants/ACLs and saved
runtime preferences are separate from this repository and were not inspected.
[Tailscale's port guidance](https://tailscale.com/docs/reference/faq/firewall-ports)
explains when opening its transport port helps. Its daemon also manages
[runtime netfilter rules](https://tailscale.com/docs/features/firewall-mode),
which must be checked on a deployed host.

OpenSSH remains disabled on both reference hosts. Its automatic firewall opening
now defaults to false, so a future host enabling SSH must select its inbound
access policy explicitly. No authorized keys, authentication changes, or public
SSH ports were invented while Moon's deployment details are deferred.

CUPS remains enabled for printing, listening on `localhost:631` with printer
sharing and its firewall opening disabled. This does not prevent printing to
network printers. GNOME's remote-desktop support remains installed on Jupiter,
but no RDP/VNC firewall exceptions are added.

## Local virtualization access

The existing rootful Docker and libvirt services and the user's `docker`, `kvm`,
and `libvirtd` memberships are retained for the existing workflows. These are
deliberate privileged-access exceptions, not isolation from applications running
as that user. Docker's group provides root-level control, as described in
[Docker's installation guidance](https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user).
Libvirt also retains its existing root-run QEMU default; changing it would
require reviewing guest storage permissions.

Docker listens on `/run/docker.sock`, with no TCP daemon endpoint. Libvirt has
no extra `--listen` arguments or custom TCP/TLS listener configuration. No remote
management ports are opened. Rootless-engine migration and VM permission changes
would be separate behavior changes.

Docker manages NAT and forwarding rules for published container ports.
Enabling the host-input firewall does not establish an allowlist for those
published ports. Leave Docker's firewall management enabled; disabling it can
break networking. Prefer explicit loopback bindings for local development
services, and review published ports on the target machine.
[Docker's firewall documentation](https://docs.docker.com/engine/network/packet-filtering-firewalls/)
describes those separate rules. Podman and libvirt networks likewise need
runtime verification.

## Nix trust

Both hosts retain only the existing NixOS and COSMIC binary caches and their
existing public keys. Signature verification and build sandboxing remain
enabled. Only `root` is a trusted Nix daemon user; neither `skylab` nor `@wheel`
is added. Ordinary daemon access remains available to all users. No additional
cache or trust grant was introduced.

The default NixOS cache URL occurs twice in the merged list because the shared
configuration also names the upstream default. This is redundant but introduces
no additional cache or key; input/cache consolidation can address it separately.

The subsequent [input/cache audit](inputs-and-caches.md) removes that duplicate
entry and limits the existing COSMIC cache/key to the COSMIC desktop. The trust
inventory above records the policy before that narrower cache scope.

## Verification and deployment boundary

The existing host-policy snapshots now also capture port ranges, per-interface
rules, trusted interfaces, reverse-path/forwarding settings, discovery/Tailscale
policy, SSH/CUPS settings, Docker endpoints, and libvirt arguments. They are
observations without custom assertion guards in the modules.

```sh
pixi run --locked just _syntax
NIXFILES_TEST_ROOT=/absolute/path/to/writable/scratch pixi run --locked baseline
```

Validated on 2026-10-19: all 44 Nix sources parsed and all 19 baseline checks
passed, including both host derivations and build plans, Hyprland evaluation,
and flake check. The report is `/tmp/nixfiles-baseline.8Ug7b2/summary.md`.
Both hosts retain empty warning lists.

The generated firewall-start script text was inspected from each derivation,
checked with Bash's syntax-only mode, and compared against the exact port rules
in the table. Both scripts trust only `lo` and end their input chain with the
refusal rule. The rule inspection report is `/tmp/nixfiles-security-rules.json`;
the scripts were not executed.

Before/after policy snapshots match except for enabling the firewall, its
upstream loopback trust, disabling automatic SSH port opening, and Mars's
Tailscale transport exception. The upstream firewall adds its iptables and
`nixos-firewall-tool` package entries; the iptables derivation was already
present elsewhere in the system list. All existing package paths/order, home
packages/files, hardware, service choices, account privileges, Nix trust, and
state versions are otherwise unchanged. The comparison report is
`/tmp/nixfiles-security-comparison.json`, with pre-change snapshots under
`/tmp/nixfiles-security-before/`.

The lockfile SHA-256 remains
`a9eb0728ead343cc10dee5a55a0ce538f40220fe4115ac641adc42f1bb9fd8dc`.

Evaluation and build plans do not prove packet filtering on a running machine.
Target validation must cover discovery, phone pairing, Tailscale connectivity,
printing, VM/container networking, and published ports from another machine.
That work stays with deployment. No firewall commands or service changes were
applied to the current non-NixOS environment.

The exact port contributions and defaults were checked in the pinned
[firewall](https://github.com/NixOS/nixpkgs/blob/89c2b2330e733d6cdb5eae7b899326930c2c0648/nixos/modules/services/networking/firewall-iptables.nix),
[KDE Connect](https://github.com/NixOS/nixpkgs/blob/89c2b2330e733d6cdb5eae7b899326930c2c0648/nixos/modules/programs/kdeconnect.nix),
[Avahi](https://github.com/NixOS/nixpkgs/blob/89c2b2330e733d6cdb5eae7b899326930c2c0648/nixos/modules/services/networking/avahi-daemon.nix),
and [Tailscale](https://github.com/NixOS/nixpkgs/blob/89c2b2330e733d6cdb5eae7b899326930c2c0648/nixos/modules/services/networking/tailscale.nix)
modules. Input pins and all state versions stay fixed.
