# User construction and package profiles

`src/lib/mk-user.nix` constructs a NixOS user account and its integrated Home
Manager configuration together, directly from its arguments. The host's call
supplies any account description, groups, and Home Manager compatibility version
it needs. The shared system module no longer defines a particular user account.

`mkHost` takes an explicit list of user modules. The flake defines Skylab's
account once in its `let` block using `skylab = mkUser { ... };`, with the complete
profile, existing description/groups, and Home Manager state version `23.11`.
Jupiter, Mars, and Moon reuse that user module:

```nix
users = [ skylab ];
```

Skylab also passes the optional Home Manager keyboard module through
`homeModules`. It selects Colemak-DH for that account in GNOME and COSMIC,
independently of package profile; other users can choose their own modules.

Selecting `profile = "minimal"` changes the user's package selection. Both
profiles import `src/home/default.nix`, which provides the shared native-file
modules, shell environment, and GTK/Qt integration. Desktop selection and
system services remain host choices; selecting minimal does not disable Docker
or libvirtd in the current shared system module.

## Package scope

| Profile | Explicit package entries | Scope |
| --- | --- | --- |
| Minimal | 59 | Daily CLI tools, Neovim, Emacs, and all shared editor helpers |
| Complete | 84 | Minimal plus 25 specialized tools, including containers, local AI, plotting, publishing, and extra fonts |

The lists live under `src/home/profiles/`. `complete.nix` extends `minimal.nix`;
`editor-helpers.nix` holds the 40 shared spell-checking, language-server, linter,
and formatter entries included in both. Compilers and general language runtimes
remain project dependencies. Neovim retains its private Node/Python providers;
Quarto in complete still has its Python/R engines disabled.

Application modules also install packages. With the current pins, integrated
Home Manager evaluates to 94 package entries for minimal and 119 for complete.
These are entry counts, not download or disk-size estimates. Keeping the full
editor-helper set means minimal still includes substantial dependencies.
Complete preserves the previous package selection; composition changes its
list order to place minimal before the extra tools.

## Constructor arguments

`mkUser` requires `name`. `profile` defaults to minimal. Optional account
arguments are `description` (defaults to the name), `homeDirectory` (defaults to
`/home/<name>`), `homeStateVersion` (defaults to `23.11` for compatibility with
existing homes), `extraGroups` and `authorizedKeys` (both default to empty), `hashedPasswordFile`
(defaults to null), and `homeModules` (defaults to empty) for additional Home
Manager modules. All user settings are inline;
the constructor does not look up per-user files or grant groups based on a name.

For example, a host can select Skylab's smaller package profile directly:

```nix
users = [ (mkUser { name = "skylab"; profile = "minimal"; }) ];
```

The shared user declaration explicitly supplies Skylab's existing description,
groups, and compatibility version. Preserve those versions on the reference
hosts. Moon currently shares the same home compatibility version; its initial
system compatibility version is `26.11`, matching the pinned platform. Revisit
Moon's initial compatibility choices if the installation release changes.
By default the constructor leaves passwords and SSH keys unconfigured.
The shared Skylab declaration passes the personal SSH public key through
`authorizedKeys`, authorizing login as Skylab on all three hosts. Shared system
defaults enable OpenSSH, allow its port through the firewall, and require
public-key authentication with direct root login disabled.

### Declarative passwords

Follow the [Moon key and encryption walkthrough](../hosts/moon-secrets.md) to
provision the shared decryption identity and keep the plaintext hash and private key
outside the repository. The encrypted hash can be committed.

`hashedPasswordFile` accepts the runtime path of a file containing one salted
password hash. For example, pass
`hashedPasswordFile = "/var/lib/nixfiles/secrets/skylab-password-hash";` to
`mkUser`. Provision that root-owned file with mode `0600` on the target before
account creation. A quoted runtime path does not copy the file into the Nix
store. Generate the hash locally with an interactive `mkpasswd` prompt; do not
put a cleartext password in a Nix option.

For an encrypted, repository-managed hash, use the already pinned agenix input.
Moon's host module now configures the encrypted password as follows (with
`config` and `inputs` in its module arguments):

```nix
imports = [ inputs.agenix.nixosModules.default ];
age.identityPaths = [ "/var/lib/agenix/identity" ];
age.secrets.skylab-password.file = ../../secrets/skylab-password.age;
users.users.skylab.hashedPasswordFile = config.age.secrets.skylab-password.path;
```

The supplied encrypted file is stored under `src/secrets/`. Agenix's
pinned NixOS module decrypts secrets before the standard user-creation activation
step. Provision the private identity before the first activation; an existing
SSH service is not required when `age.identityPaths` is explicit. See the
[agenix documentation](https://github.com/ryantm/agenix).

The current `users.mutableUsers = true` permits subsequent password changes
with `passwd`; the declared value initializes the account. For enforced
declarative passwords on every activation, set `users.mutableUsers = false`
only after configuring credentials for the accounts that need access. That
option applies to the whole host, not just Skylab. Moon uses the encrypted hash
to initialize Skylab's password; Jupiter and Mars retain their existing account
configuration. No system has been activated by this repository change.

User modules share the host's overlaid package set through integrated Home
Manager. No standalone Home Manager activation or additional flake input is
introduced. Live dotfile anchors still follow each user's XDG data directory.

## Verification

The repository checks parse all Nix modules and exercise the existing portable
configuration and workflow tests. The host baseline now evaluates all three
hosts, their Home Manager generations, and system build plans.
Full system builds and target-machine activation remain separate checks.

Validation on 2026-10-20 passed:

- Repository lint, parsing of 49 Nix files, portable component checks, and
  workflow tests (`/tmp/nixfiles-mkuser-inline-check.log`).
- Both complete reference hosts retain identical full system derivation paths
  and policy observations after removing the per-user file, with no warnings
  (`/tmp/nixfiles-mkuser-inline-{jupiter,mars}.json`). The earlier profile baseline
  passed all 19 checks (`/tmp/nixfiles-baseline.Xu3LcU/summary.md`).
- Before/after package comparison preserves all 119 home entries, identity,
  groups, compatibility versions, hardware, services, and access policies.
  The profile split changes only the generated fontconfig reference to the
  recomposed home profile; font settings and native links remain unchanged.
- The two-argument minimal call works without a per-user file. Two-user
  evaluation verifies account defaults, explicit custom home/state version/
  groups/XDG settings, activation derivations, all 26 native targets, and all
  40 shared editor helpers (`/tmp/nixfiles-mkuser-inline-validation.json`).

The shared `skylab` declaration and Moon configuration also pass the expanded
26-check baseline (`/tmp/nixfiles-baseline.ozD7Wd/summary.md`). Jupiter and Mars
retain identical system derivations and policy observations; all three hosts
use the same complete home package selection and account settings.
