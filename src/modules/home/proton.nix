{ config, inputs, lib, pkgs, ... }:

let
  drive = inputs.proton-drive-linux.packages.${pkgs.stdenv.hostPlatform.system}.default;
  unitFiles = [
    "systemd/user/proton-drive.service"
    "systemd/user/graphical-session.target.wants/proton-drive.service"
  ];
in
{
  home.packages = [ drive pkgs.proton-pass-cli ];

  # Use the desktop Secret Service; the kernel backend can deny session access
  # on NixOS and loses its encryption key at reboot.
  # https://github.com/NixOS/nixpkgs/issues/519229
  home.sessionVariables.PROTON_PASS_LINUX_KEYRING = "dbus";
  systemd.user.sessionVariables.PROTON_PASS_LINUX_KEYRING =
    config.home.sessionVariables.PROTON_PASS_LINUX_KEYRING;

  # Keep the tray optional; the mount starts independently with the session.
  xdg.configFile."autostart/io.narl.proton-drive-linux-tray.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Proton Drive Tray
    Hidden=true
  '';

  # Install the upstream unit only for this user, with NixOS's FUSE helper path.
  xdg.configFile."systemd/user/proton-drive.service" = {
    force = true;
    text = builtins.replaceStrings
      [ "ExecStart=/usr/bin/pdfs" "[Service]" ]
      [
        "ExecStart=${drive}/bin/pdfs"
        # FUSE needs NixOS's privileged wrapper, rather than the unwrapped binary.
        "[Service]\nEnvironment=PATH=/run/wrappers/bin:/run/current-system/sw/bin"
      ]
      (builtins.readFile (inputs.proton-drive-linux + "/packaging/proton-drive.service"));
  };

  # Manage the enablement link too, so it follows unit changes on every rebuild.
  xdg.configFile."systemd/user/graphical-session.target.wants/proton-drive.service" = {
    force = true;
    source = config.xdg.configFile."systemd/user/proton-drive.service".source;
  };

  # Login calls `systemctl --user reenable`, which can replace our managed links.
  # Allow only these generated files to be reclaimed, preserving foreign copies
  # after collision checks but before Home Manager installs its replacement links.
  home.activation.backupProtonDriveUnits = lib.hm.dag.entryBetween
    [ "linkGeneration" ] [ "writeBoundary" ] ''
      for target in ${lib.escapeShellArgs (map (file: "${config.xdg.configHome}/${file}") unitFiles)}; do
        if [[ -L "$target" ]]; then
          link="$(${pkgs.coreutils}/bin/readlink "$target")"
          if [[ "$link" == ${builtins.storeDir}/*-home-manager-files/* ]]; then
            continue
          fi
        elif [[ ! -e "$target" ]]; then
          continue
        elif [[ ! -f "$target" ]]; then
          printf 'Expected a service file at %s; refusing to replace it.\n' "$target" >&2
          exit 1
        fi
        run ${pkgs.coreutils}/bin/mv -T --backup=numbered -- "$target" "$target.before-home-manager"
      done
    '';
}
