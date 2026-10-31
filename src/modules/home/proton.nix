{ inputs, pkgs, ... }:

let
  drive = inputs.proton-drive-linux.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  home.packages = [ drive pkgs.proton-pass-cli ];

  # The package ships a tray autostart entry; keep the initial trial opt-in.
  xdg.configFile."autostart/io.narl.proton-drive-linux-tray.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Proton Drive Tray
    Hidden=true
  '';

  # Install the upstream unit only for this user. Unlike systemd.user.services,
  # this does not create a wantedBy link: enabling the mount is a local choice.
  xdg.configFile."systemd/user/proton-drive.service".text = builtins.replaceStrings
    [ "ExecStart=/usr/bin/pdfs" "[Service]" ]
    [
      "ExecStart=${drive}/bin/pdfs"
      # FUSE needs NixOS's privileged wrapper, rather than the unwrapped binary.
      "[Service]\nEnvironment=PATH=/run/wrappers/bin:/run/current-system/sw/bin"
    ]
    (builtins.readFile (inputs.proton-drive-linux + "/packaging/proton-drive.service"));
}
