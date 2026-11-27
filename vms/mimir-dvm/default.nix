# =============================================================================
# mimir-dvm — mimir's rootful Docker + Komodo microVM guest
# =============================================================================
#
# Standalone guest (nixosConfigurations.mimir-dvm), run on the mimir NAS by
# reference via ft.microvms.instances.mimir-dvm in machines/mimir/default.nix.
# Komodo on plaintext defaults; persistent state on the auto host share at
# /srv/host-share. The tap interface (name + MAC) is derived from the VM name by
# the guest baseline, so it always matches the host's ft.microvms lease.
#
# TODO: add admin SSH public key(s) for docker-vm access once known
# (services.openssh + users.users.root.openssh.authorizedKeys, as in
# vms/strix-dvm). Komodo [secrets] / host auto-apply pending the decoupled
# guest-secrets design.
# =============================================================================
{ ... }:
{
  # The tap interface (name + MAC) is auto-derived from the VM name by the guest
  # baseline, matching the host's ft.microvms lease — nothing to declare here.

  microvm.volumes = [
    {
      image = "/var/lib/microvm/mimir-dvm/docker.img";
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
