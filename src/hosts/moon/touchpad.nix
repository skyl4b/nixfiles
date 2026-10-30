{ config, pkgs, ... }:

let
  resetTouchpad = pkgs.writeShellScript "surface-touchpad-reset" ''
    set -euo pipefail
    driver="/sys/bus/hid/drivers/hid-multitouch"

    # Give the Type Cover time to initialize after boot or resume.
    ${pkgs.coreutils}/bin/sleep 3
    shopt -s nullglob
    found=false

    for device in "$driver"/*045E:09B5.*; do
      [[ -L "$device" ]] || continue
      found=true
      id="''${device##*/}"
      printf 'Resetting Surface touchpad: %s\n' "$id"
      printf '%s' "$id" > "$driver/unbind"
      ${pkgs.coreutils}/bin/sleep 0.5
      printf '%s' "$id" > "$driver/bind"
    done

    if ! "$found"; then
      printf 'No Surface touchpad matching 045E:09B5 is bound to hid-multitouch; skipping.\n'
    fi
  '';
in
{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "my-reset-touchpad" ''
      exec ${config.systemd.package}/bin/systemctl start surface-touchpad-reset.service
    '')
  ];

  # A repeatable oneshot also serializes manual and automatic reset requests.
  systemd.services.surface-touchpad-reset = {
    description = "Reset Surface Type Cover touchpad";
    wantedBy = [ "graphical.target" ];
    after = [ "display-manager.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = resetTouchpad;
    };
  };

  # Queue the same service without holding up the resume hook for its delay.
  powerManagement.resumeCommands = ''
    ${config.systemd.package}/bin/systemctl --no-block start surface-touchpad-reset.service
  '';
}
