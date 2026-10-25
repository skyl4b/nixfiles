# Moon's encrypted login password

The repository supports a runtime password-hash file and records the shared
`nixfiles-secrets` public key plus the personal recovery public key in
`src/secrets/secrets.nix`. The encrypted password hash is stored in
`src/secrets/skylab-password.age` and wired into Moon's account configuration.
Private-key provisioning on the target is still required before installation.
Keep the password, its unencrypted hash, and private keys local to the machines
where you create and provision them.

## Provision the shared decryption identity

Agenix needs a private decryption identity that root can use without a prompt
during activation, before account creation. The chosen `nixfiles-secrets` key is
shared across hosts. Declare its runtime path in `age.identityPaths`; enabling
the SSH server is unnecessary.

The shared secrets key keeps the personal SSH private key separate from the
identity provisioned onto every host. Reusing one secrets key means a host with
that private key can decrypt every secret encrypted to it. Keep an off-device
backup and replace the shared key on all hosts if it is compromised.

Reuse the private key matching the recorded public key; no new key needs to be
generated. It must be usable without a passphrase prompt during activation.
Securely provision the same private key as root-owned mode `0600` at
`/var/lib/agenix/identity` on each target host, with its parent directory mode
`0700`. Keep a backup off Moon before replacing its current OS. Provisioning is
separate from committing the repository.

On each installed host, copy the existing key using an absolute source path:

```sh
pixi run --locked provision-identity "$HOME/.ssh/nixfiles-secrets"
```

Use the actual location of your private key in place of that example. From the
installer, after mounting the target filesystems, specify the target root:

```sh
pixi run --locked provision-identity /absolute/path/to/nixfiles-secrets /mnt
```

The recipe uses `sudo`, sets root ownership and directory/file permissions, and
refuses to replace a different existing identity. It does not generate a key,
enable SSH, or activate the system. Run it in the environment that can access
the target filesystem; running it inside a distrobox may provision the container
rather than the host.

Both recorded recipients can decrypt the encrypted hash. The personal private
key can remain on the machine used to edit secrets.

Never add a private key to the repository or refer to it with a Nix path literal,
which would copy it into the Nix store.

## Generate and encrypt the hash locally

The recipient policy for `skylab-password.age` already includes both public keys.
Creating the encrypted file needs only those public keys; the private key does
not need to be provisioned on the editing machine. Reopening an existing file
requires a matching private key, at any readable location.

Generate the password hash on the development machine using an interactive
password prompt. From the repository checkout:

```sh
pixi run --locked just _nix shell .#nixosConfigurations.moon.pkgs.mkpasswd \
  -c mkpasswd --method=yescrypt
```

The password is not passed as a command-line argument. The resulting hash stays
local. Next, open the encrypted secret's temporary editor and put exactly that
one hash line in it:

```sh
pixi run --locked just _nix shell .#nixosConfigurations.moon.pkgs.agenix \
  -c sh -c 'cd src/secrets && exec agenix -e skylab-password.age'
```

The recipe starts at the checkout root; its child shell changes into
`src/secrets` so agenix uses that directory's `secrets.nix` recipient policy.
Commit only the encrypted `.age`
file and the public recipient policy. The agenix editor workflow needs a private
key belonging to an existing recipient when reopening an encrypted file; use
its `--identity` option when that key is not in a default SSH identity location.
For example, to edit using the original shared private key:

```sh
pixi run --locked just _nix shell .#nixosConfigurations.moon.pkgs.agenix \
  -c sh -c 'cd src/secrets && exec agenix -e skylab-password.age --identity "$1"' \
  sh "$HOME/.ssh/nixfiles-secrets"
```

Keep using the user-readable original for editing; the provisioned root-owned
copy is for activation.

Moon imports the pinned agenix NixOS module, declares the identity path and
encrypted file, and binds Skylab's `hashedPasswordFile` to the decrypted secret.
The module wiring and mutable-password behavior are described in
[declarative password setup](../modernization/user-profiles.md#declarative-passwords).
The pinned module orders decryption before standard account creation.

The identity must be provisioned into the mounted target before `nixos-install`
runs activation, rather than waiting until the first reboot. Test decryption
locally before installation without displaying the password hash:

```sh
pixi run --locked just _nix shell .#nixosConfigurations.moon.pkgs.agenix \
  -c sh -c 'cd src/secrets && exec agenix -d skylab-password.age --identity "$1" >/dev/null' \
  sh "$HOME/.ssh/nixfiles-secrets"
```

A successful exit confirms decryption; it does not check that the encrypted
contents are a valid password hash. See the [upstream agenix tutorial](https://github.com/ryantm/agenix#tutorial).
