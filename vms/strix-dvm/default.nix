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
{ lib, config, ... }:
let
  # Auto-join the tailnet once the guest's sops file exists: komodo.yaml is
  # created in the same runbook step that turns Periphery secrets on, so gate
  # on that toggle (gating on ft.vmSecrets alone would fail activation before
  # the file exists). Until then, join once by hand: ssh root@10.0.100.2 tailscale up
  autoJoinTailnet = config.ft.komodo.secrets.periphery.enable;
in
{
  # The tap interface (name + MAC) is auto-derived from the VM name by the guest
  # baseline, matching the host's ft.microvms lease — nothing to declare here.

  microvm.volumes = [
    {
      image = "/var/lib/microvm/strix-dvm/docker.img";
      mountPoint = "/var/lib/docker";
      # 60 GiB: all stacks' images + named volumes (metrics, logs, AnythingLLM).
      # microvm only creates the image when absent — an existing 20 GiB
      # docker.img must be grown by hand (see containers/komodo-gitops-setup.md).
      size = 61440;
    }
    {
      # tailscaled state: the guest root is wiped on restart, and without this
      # the VM would register as a brand-new tailnet node on every boot.
      image = "/var/lib/microvm/strix-dvm/tailscale.img";
      mountPoint = "/var/lib/tailscale";
      size = 64;
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

  # Tailnet node "strix-dvm": Caddy (containers/discoverability.yaml) serves
  # every web UI at http://strix-dvm/<app>/.
  ft.tailscale = {
    enable = true;
    enableTrayApp = false;
    # autoJoin wires the key through ft.sops, which a microVM guest doesn't
    # use (its sops comes from ft.vmSecrets) — so the key is wired below.
    autoJoin = false;
  };
  sops.secrets."tailscale/authkey" = lib.mkIf autoJoinTailnet { };
  services.tailscale.authKeyFile =
    lib.mkIf autoJoinTailnet
      config.sops.secrets."tailscale/authkey".path;

  ft.containers = {
    enable = true;
    runtime = "docker";
    rootless = false;
    compose.enable = true;
  };

  # Guest sops plumbing: mounts the host-shared /var/secrets and decrypts
  # komodo.yaml on the guest's persistent host key. Declares no secrets by
  # itself — they come from ft.komodo.secrets.* (runbook section B).
  ft.vmSecrets.enable = true;

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
