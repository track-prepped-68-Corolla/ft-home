# =============================================================================
# mimir-docker — mimir's rootful Docker + Komodo microVM guest
# =============================================================================
#
# Standalone guest (nixosConfigurations.mimir-docker), run on the mimir NAS by
# reference via ft.microvms.instances.mimir-docker in machines/mimir/default.nix.
# Komodo on plaintext defaults; persistent state on the auto host share at
# /srv/host-share. The tap MAC here matches the host instance's vmMac.
#
# TODO: add admin SSH public key(s) for docker-vm access once known
# (services.openssh + users.users.root.openssh.authorizedKeys, as in
# vms/strix-docker). Komodo [secrets] / host auto-apply pending the decoupled
# guest-secrets design.
# =============================================================================
{ ... }:
{
  microvm.interfaces = [
    {
      type = "tap";
      id = "tap-mimir-docker";
      mac = "02:00:00:00:00:02";
    }
  ];

  microvm.volumes = [
    {
      image = "/var/lib/microvm/mimir-docker/docker.img";
      mountPoint = "/var/lib/docker";
      size = 20480;
    }
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
