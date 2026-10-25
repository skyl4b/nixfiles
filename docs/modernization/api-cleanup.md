# API cleanup (NIX-14)

This pass migrates the APIs in the existing pinned configurations. It does not
update inputs or state versions. Jupiter and Mars remain evaluation references;
deployment and hardware verification are deferred.

| Area | Change | Result |
| --- | --- | --- |
| GNOME/GDM | `services.xserver.{desktopManager,displayManager}` → `services.{desktopManager,displayManager}` | Jupiter keeps GNOME and GDM enabled |
| PulseAudio | `hardware.pulseaudio.enable` → `services.pulseaudio.enable` | PulseAudio remains disabled; PipeWire's PulseAudio support remains enabled |
| Package priority | `pkgs.hiPrio` → `lib.hiPrio` | GCC and Jupyter keep their priority and derivations |
| Home Qt integration | `platformTheme.name = "adwaita"` replaces `"gnome"` | Qt 5/6 use qadwaitadecorations instead of QGnomePlatform; `adwaita-dark` stays selected |
| NVIDIA containers | Both `enableNvidia` flags → `hardware.nvidia-container-toolkit.enable` | GPU access uses CDI device requests |
| Unused Hyprland module | Qt platform `"kde6"` → `"kde"`; removed KDE 5 packages → `kdePackages`; `qt6ct` → `qt6Packages.qt6ct` | The retained desktop module evaluates against the pin |

The package-priority alias is exactly `lib.hiPrio` in the pinned source. Other
home font and language-server selections already evaluate without deprecation
warnings and stay unchanged. Git and Yazi's configuration migrations were
handled in their earlier native-file passes.

## NVIDIA container behavior

This is a runtime migration, not a rename with identical Docker behavior. The
old Docker flag installed the NVIDIA wrapper and made it the default runtime.
The old Podman flag had no GPU-enabling effect in the pinned module.

The toolkit option enables Docker's CDI feature and configures the container
engine's CDI search paths. NixOS generates
`/run/cdi/nvidia-container-toolkit.json` using the service
`nvidia-container-toolkit-cdi-generator.service`, wanted at boot and required by
the enabled Docker/Podman services. Jupiter enables Docker; Mars enables both.
The legacy NVIDIA runtime configuration and Docker default-runtime override are
removed. Existing containers that rely on that wrapper need their GPU request
updated when deployment resumes.

On a deployed host with the NVIDIA driver and CDI generator working, request
GPUs explicitly, for example:

```sh
docker run --rm --device nvidia.com/gpu=all ubuntu nvidia-smi -L
podman run --rm --device nvidia.com/gpu=all ubuntu nvidia-smi -L
```

These are future target-machine smoke tests; they were not run in this
non-NixOS container. No images were pulled and no container engine or system
service was configured here. Keep the old `--runtime=nvidia`/`--gpus` usage under
review rather than assuming those commands are interchangeable with CDI.

The selected driver's PRIME IDs, offload settings, power management, graphics
packages, kernel settings, filesystems, and swap devices remain unchanged.
Mars's old `intelBusId` on an AMD host still needs physical verification.

## Validation

The baseline's host-policy snapshots now include canonical GDM/PulseAudio
values, Qt theme/session values, container daemon settings, CDI service
configuration, and the presence of the legacy NVIDIA configuration. This makes
the behavior changes visible alongside the existing hardware/account/package
snapshots. These are observations, without custom Nix assertion guards.

Neither reference host imports Hyprland. A small container evaluation fixture
now forces that module's toplevel derivation and packages, catching its invalid
Qt enum and removed package references. The baseline therefore has 19 checks.
This fixture proves evaluation only, not a graphical session or deployment.

```sh
pixi run --locked check
NIXFILES_TEST_ROOT=/absolute/path/to/writable/scratch pixi run --locked baseline
```

Validated on 2026-10-19: the portable `check` suite passed; after adding the
Hyprland fixture, syntax checks parsed all 44 Nix sources and recipe linting
passed. All 19 baseline checks passed, including both host derivations, build
plans, the Hyprland evaluation, and flake check. The report is
`/tmp/nixfiles-baseline.nW8m7X/summary.md`.

Both hosts now report an empty warning list, and derivation evaluation emits no
previous deprecation traces. The earlier sandboxed collector failed only its
two cache-querying build plans because DNS was unavailable; the network-enabled
rerun above passed.

Compared with the saved pre-API policy snapshots in `/tmp/nixfiles-api-before/`,
storage, GPU bus IDs, graphics packages, kernel settings, services, accounts,
network/Nix policy, and exact system package paths/order match. Home packages
retain their paths/order apart from the two Qt integration packages and the
derived session-variable script. The only changed home-file entries are the Qt
environment file and fontconfig's reference to the changed home package profile.
Native dotfiles and their link definitions are unchanged.

The lockfile SHA-256 remains
`a9eb0728ead343cc10dee5a55a0ce538f40220fe4115ac641adc42f1bb9fd8dc`.
System state versions remain Jupiter 23.11 and Mars 24.11; both homes retain
23.11. No complete system build, activation, GUI session, or GPU workload was
tested in this pass.

## Sources

The checked-in lockfile supplies the relevant versions; local pinned sources
were inspected before editing:

- [NixOS NVIDIA toolkit module at the pin](https://github.com/NixOS/nixpkgs/blob/89c2b2330e733d6cdb5eae7b899326930c2c0648/nixos/modules/services/hardware/nvidia-container-toolkit/default.nix)
- [NixOS 24.05 NVIDIA migration note](https://github.com/NixOS/nixpkgs/blob/89c2b2330e733d6cdb5eae7b899326930c2c0648/nixos/doc/manual/release-notes/rl-2405.section.md)
- [Pinned Home Manager Qt module](https://github.com/nix-community/home-manager/blob/d10a9b16b2a3ee28433f3d1c603f4e9f1fecb8e1/modules/misc/qt.nix)
- [NVIDIA CDI device requests](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/cdi-support.html#running-a-workload-with-cdi)
- [Docker CDI support](https://docs.docker.com/reference/cli/dockerd/#enable-cdi-devices)

Current upstream NVIDIA documentation describes its own refresh service. The
pinned NixOS module above defines the different service name and output path
used by this repository.
