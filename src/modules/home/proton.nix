{ config, inputs, lib, pkgs, ... }:

let
  drive = inputs.proton-drive-linux.packages.${pkgs.stdenv.hostPlatform.system}.default;
  unitFiles = [
    "systemd/user/proton-drive.service"
    "systemd/user/graphical-session.target.wants/proton-drive.service"
  ];
in
{
  imports = [ ./proton-ssh-agent.nix ];

  home.packages = [ drive ];

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

  # Reuse the package's unit in the user vendor-data layer. The client owns the
  # config-layer links it creates with `systemctl --user reenable` after login.
  xdg.dataFile."systemd/user/proton-drive.service".source =
    "${drive}/lib/systemd/user/proton-drive.service";

  # This dependency starts the packaged unit with the session without managing
  # the config-layer enablement link that the client rewrites.
  xdg.dataFile."systemd/user/graphical-session.target.wants/proton-drive.service".source =
    "${drive}/lib/systemd/user/proton-drive.service";

  # FUSE needs NixOS's privileged wrapper, rather than the unwrapped binary.
  xdg.configFile."systemd/user/proton-drive.service.d/nixos.conf".text = ''
    [Service]
    Environment=PATH=/run/wrappers/bin:/run/current-system/sw/bin
  '';

  # Remove the former generated unit and any links recreated by the client.
  # Otherwise a config-layer link could pin an older package ahead of the new
  # vendor unit. These generated service links contain no application state.
  home.activation.clearProtonDriveUnitLinks = lib.hm.dag.entryBetween
    [ "linkGeneration" ] [ "writeBoundary" ] ''
      run ${pkgs.coreutils}/bin/rm -f -- ${lib.escapeShellArgs (map (file: "${config.xdg.configHome}/${file}") unitFiles)}
    '';
}
