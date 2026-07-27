# =============================================================================
# strix-docker — strix's rootful Docker + Komodo microVM guest
# =============================================================================
#
# Standalone guest (nixosConfigurations.strix-docker), run on strix by reference
# via ft.microvms.instances.strix-docker in machines/strix/default.nix. Komodo
# on plaintext defaults; persistent state on the auto host share at
# /srv/host-share. The tap MAC here matches the host instance's vmMac.
#
# Komodo [secrets] / host auto-apply are not wired yet — pending the decoupled
# guest-secrets design (a standalone guest can't read strix's repoPath-relative
# sops tree the way the old inline ft.dockervm guest did).
# =============================================================================
{ ... }:
{
  microvm.interfaces = [
    {
      type = "tap";
      id = "tap-strix-docker";
      mac = "02:00:00:00:00:01";
    }
  ];

  microvm.volumes = [
    {
      image = "/var/lib/microvm/strix-docker/docker.img";
      mountPoint = "/var/lib/docker";
      size = 20480;
    }
  ];

  # Root login into the guest for docker-vm access (was ft.dockervm.sshAuthorizedKeys).
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;
  users.users.root.openssh.authorizedKeys.keys = [
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIDgZCe1UZA1E7bCpTWz5NUMHlGUq16nOobSJ2LyyZCP2AAAABHNzaDo= track-prepped-68-Corolla@protonmail.com"
  ];

  ft.containers = {
    enable = true;
    runtime = "docker";
    rootless = false;
    compose.enable = true;
  };

  ft.komodo = {
    enable = true;
    backupsPath = "/srv/host-share/backups";
    peripheryRootDirectory = "/srv/host-share/periphery";
    repoCachePath = "/srv/host-share/repo-cache";
    syncPath = "/srv/host-share/syncs";
    includeDiskMounts = [
      "/"
      "/var/lib/docker"
      "/srv/host-share"
    ];
  };
}
