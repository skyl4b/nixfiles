{ config, inputs, pkgs, ... }:

let
  drive = inputs.proton-drive-linux.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  home.packages = [ drive pkgs.proton-pass-cli ];

  # Keep the tray optional; the mount starts independently with the session.
  xdg.configFile."autostart/io.narl.proton-drive-linux-tray.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Proton Drive Tray
    Hidden=true
  '';

  # Install the upstream unit only for this user, with NixOS's FUSE helper path.
  xdg.configFile."systemd/user/proton-drive.service".text = builtins.replaceStrings
    [ "ExecStart=/usr/bin/pdfs" "[Service]" ]
    [
      "ExecStart=${drive}/bin/pdfs"
      # FUSE needs NixOS's privileged wrapper, rather than the unwrapped binary.
      "[Service]\nEnvironment=PATH=/run/wrappers/bin:/run/current-system/sw/bin"
    ]
    (builtins.readFile (inputs.proton-drive-linux + "/packaging/proton-drive.service"));

  # Manage the enablement link too, so it follows unit changes on every rebuild.
  xdg.configFile."systemd/user/graphical-session.target.wants/proton-drive.service".source =
    config.xdg.configFile."systemd/user/proton-drive.service".source;
}
