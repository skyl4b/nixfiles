{ config, lib, pkgs, ... }:

{
  # Home Manager publishes the socket to shells, systemd, and D-Bus, retaining
  # a forwarded SSH_AUTH_SOCK when SSH_CONNECTION is set.
  sshAuthSock = {
    enable = true;
    initialization = {
      bash = ''export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/proton-pass-ssh-agent/agent.sock"'';
      fish = ''set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/proton-pass-ssh-agent/agent.sock"'';
      nushell = ''$env.SSH_AUTH_SOCK = ($env.XDG_RUNTIME_DIR | path join "proton-pass-ssh-agent" "agent.sock")'';
    };
    systemd.socketProviderUnit = "proton-pass-ssh-agent.service";
  };

  # Bash remains unmanaged. mkHost sources this helper from /etc/profile, so
  # login Bash also gets the socket without overwriting SSH agent forwarding.
  home.sessionVariablesExtra = ''
    if [ -z "''${SSH_AUTH_SOCK:-}" ] || [ -z "''${SSH_CONNECTION:-}" ]; then
      ${config.sshAuthSock.initialization.bash}
    fi
  '';

  # Replace only this user's GCR agent; keep GNOME Keyring's Secret Service.
  xdg.configFile = lib.genAttrs [
    "systemd/user/gcr-ssh-agent.service"
    "systemd/user/gcr-ssh-agent.socket"
  ] (_: { source = config.lib.file.mkOutOfStoreSymlink "/dev/null"; });

  systemd.user.services.proton-pass-ssh-agent = {
    Unit = {
      Description = "Proton Pass SSH agent";
      Documentation = [ "https://protonpass.github.io/pass-cli/commands/ssh-agent/" ];
      After = [ "graphical-session-pre.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${lib.getExe pkgs.proton-pass-cli} ssh-agent start --socket-path %t/proton-pass-ssh-agent/agent.sock";
      Environment = [ "PROTON_PASS_LINUX_KEYRING=dbus" ];
      RuntimeDirectory = "proton-pass-ssh-agent";
      RuntimeDirectoryMode = "0700";
      UMask = "0077";
      Restart = "on-failure";
      RestartSec = 30;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
