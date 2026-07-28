# =============================================================================
# strix-dvm — strix's rootful Docker + Komodo microVM guest
# =============================================================================
#
# Standalone guest (nixosConfigurations.strix-dvm), run on strix by reference via
# ft.microvms.instances.strix-dvm in machines/strix/default.nix. Komodo on
# plaintext defaults; persistent state on the auto host share at /srv/host-share.
# The tap interface (name + MAC) is derived from the VM name by the guest
# baseline, so it always matches the host's ft.microvms lease.
#
# Komodo [secrets] / host auto-apply are not wired yet — pending the decoupled
# guest-secrets design (a standalone guest can't read strix's repoPath-relative
# sops tree the way the old inline ft.dockervm guest did).
# =============================================================================
{ ... }:
{
  # The tap interface (name + MAC) is auto-derived from the VM name by the guest
  # baseline, matching the host's ft.microvms lease — nothing to declare here.

  microvm.volumes = [
    {
      image = "/var/lib/microvm/strix-dvm/docker.img";
      mountPoint = "/var/lib/docker";
      size = 20480;
    }
  ];

  # Root login into the guest for docker-vm access (was ft.dockervm.sshAuthorizedKeys).
  # Key-only: disable both password and keyboard-interactive (PAM) auth so root
  # can only log in with the authorized key below.
  services.openssh.enable = true;
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };
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
