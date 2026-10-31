{ config, pkgs, ... }:

let
  resetTouchpad = pkgs.writeShellScript "surface-touchpad-reset" ''
    set -euo pipefail
    driver="/sys/bus/usb/drivers/usbhid"
    declare -A interfaces=()

    # Give the Type Cover time to initialize after boot or resume.
    ${pkgs.coreutils}/bin/sleep 3
    shopt -s nullglob
    # Find the USB interface above the touchpad, not the cover's keyboard interfaces.
    # Rebinding hid-multitouch alone does not reliably recover after system suspend.
    # https://community.fydeos.io/t/topic/37340/8
    for attempt in {1..5}; do
      for device in /sys/bus/hid/devices/0003:045E:09B5.*; do
        [[ -L "$device/driver" ]] || continue
        hid_driver="$(${pkgs.coreutils}/bin/readlink -f "$device/driver")"
        [[ "''${hid_driver##*/}" == hid-multitouch ]] || continue
        interface="$(${pkgs.coreutils}/bin/readlink -f "$device")"
        while [[ "$interface" != / && ! -f "$interface/bInterfaceNumber" ]]; do
          interface="$(${pkgs.coreutils}/bin/dirname "$interface")"
        done
        [[ -f "$interface/bInterfaceNumber" && -L "$interface/driver" ]] || continue
        [[ "$(${pkgs.coreutils}/bin/readlink -f "$interface/driver")" == "$driver" ]] || continue
        interfaces["''${interface##*/}"]="$interface"
      done
      if (( ''${#interfaces[@]} > 0 )); then break; fi
      if (( attempt < 5 )); then ${pkgs.coreutils}/bin/sleep 1; fi
    done

    if (( ''${#interfaces[@]} == 0 )); then
      printf 'No Surface touchpad USB interface found for 045E:09B5; skipping.\n'
      exit 0
    fi

    # Retain the USB interface ID across removal/recreation of its HID children.
    # Retry failed binds and attempt restoration if interrupted while unbound.
    pending=""
    bind_interface() {
      local attempt
      for attempt in {1..3}; do
        if printf '%s' "$pending" > "$driver/bind"; then return 0; fi
        if (( attempt < 3 )); then ${pkgs.coreutils}/bin/sleep 1; fi
      done
      return 1
    }
    restore_interface() {
      if [[ -n "$pending" ]]; then
        printf 'Restoring Surface touchpad USB interface: %s\n' "$pending" >&2
        bind_interface || true
      fi
    }
    trap restore_interface EXIT
    trap 'exit 143' TERM
    trap 'exit 130' INT

    for id in "''${!interfaces[@]}"; do
      printf 'Resetting Surface touchpad USB interface: %s\n' "$id"
      pending="$id"
      if ! printf '%s' "$id" > "$driver/unbind"; then
        pending=""
        exit 1
      fi
      ${pkgs.coreutils}/bin/sleep 1
      bind_interface
      pending=""
      printf 'Rebound Surface touchpad USB interface: %s\n' "$id"
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
