{ config, lib, ... }:

{
  options.ft.runtimeFacts.enable = lib.mkEnableOption "write host facts to /etc/ft/facts/ at activation";

  config = lib.mkIf config.ft.runtimeFacts.enable {
    system.activationScripts.ftFacts = ''
      mkdir -p /etc/ft/facts
      echo -n "${config.networking.hostName}"  > /etc/ft/facts/hostname
      echo -n "${config.ft.repoPath}"          > /etc/ft/facts/repo-path
      if [ -f /etc/ssh/ssh_host_ed25519_key.pub ]; then
        cp /etc/ssh/ssh_host_ed25519_key.pub /etc/ft/facts/ssh-host-pubkey
      fi
    '';

    system.activationScripts.ftRepoPath = ''
      mkdir -p /var/ft
      echo -n "${config.ft.repoPath}" > /var/ft/repo-path
    '';
  };
}
