{ config, pkgs, ... }:

let
  resetTouchpad = pkgs.writeShellScript "surface-touchpad-reset" ''
    set -euo pipefail
    # Give the Type Cover time to initialize after boot or resume.
    ${pkgs.coreutils}/bin/sleep 3
    shopt -s nullglob
    devices=()

    # A full USB device reset recovered Moon when HID and USB-interface rebinds
    # completed successfully but still produced no touchpad input after resume.
    # Discover the cover by USB ID; port paths and bus/device numbers can change.
    for attempt in {1..5}; do
      for device in /sys/bus/usb/devices/*; do
        [[ -f "$device/idVendor" && -f "$device/idProduct" ]] || continue
        [[ "$(<"$device/idVendor")" == 045e && "$(<"$device/idProduct")" == 09b5 ]] || continue
        devices+=("$device")
      done
      if (( ''${#devices[@]} > 0 )); then break; fi
      if (( attempt < 5 )); then ${pkgs.coreutils}/bin/sleep 1; fi
    done

    if (( ''${#devices[@]} == 0 )); then
      printf 'No Surface Type Cover USB device matching 045e:09b5; skipping.\n'
      exit 0
    fi

    for device in "''${devices[@]}"; do
      bus="$(<"$device/busnum")"
      number="$(<"$device/devnum")"
      [[ "$bus" =~ ^[0-9]+$ && "$number" =~ ^[0-9]+$ ]] || {
        printf 'Invalid USB bus/device numbers for %s.\n' "$device" >&2
        exit 1
      }
      printf -v address '%03d/%03d' "$((10#$bus))" "$((10#$number))"
      printf 'Resetting Surface Type Cover USB device: %s (045e:09b5)\n' "$address"
      if output="$(${pkgs.usbutils}/bin/usbreset "$address" 2>&1)"; then
        printf '%s\n' "$output"
        # usbutils 019 returns zero even if the reset ioctl fails. Check its
        # success message too, so systemd reports a failed reset accurately.
        [[ "$output" == *' ... ok' ]] || {
          printf 'USB reset did not report success for %s.\n' "$address" >&2
          exit 1
        }
      else
        printf '%s\n' "$output" >&2
        exit 1
      fi
    done
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
      TimeoutStartSec = 30;
    };
  };

  # Queue the same service without holding up the resume hook for its delay.
  powerManagement.resumeCommands = ''
    ${config.systemd.package}/bin/systemctl --no-block start surface-touchpad-reset.service
  '';
}
