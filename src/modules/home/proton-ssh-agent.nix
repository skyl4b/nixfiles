{ config, lib, ... }:

{
  services.proton-pass-agent.enable = true;

  # Bash remains unmanaged. mkHost sources this helper from /etc/profile, so
  # login Bash also gets the socket without overwriting SSH agent forwarding.
  home.sessionVariablesExtra = ''
    if [ -z "''${SSH_AUTH_SOCK:-}" ] || [ -z "''${SSH_CONNECTION:-}" ]; then
      ${config.sshAuthSock.initialization.bash}
    fi
  '';

  # GCR's socket resets SSH_AUTH_SOCK in the user manager when started.
  # Replace only this user's agent; keep GNOME Keyring's Secret Service.
  xdg.configFile = lib.genAttrs [
    "systemd/user/gcr-ssh-agent.service"
    "systemd/user/gcr-ssh-agent.socket"
  ] (_: { source = config.lib.file.mkOutOfStoreSymlink "/dev/null"; });
}
