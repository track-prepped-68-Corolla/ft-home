# =============================================================================
# mimir — NAS Host Configuration
# =============================================================================
#
# Discovered by lib/generator.nix at machines/mimir/default.nix
# and becomes nixosConfigurations.mimir.
#
# PROVISIONING CHECKLIST
#   1. Boot target into the ft-home live ISO; git clone the ft-home consumer repo
#   2. Run nixos-facter; commit output to machines/mimir/var/facter.json
#   3. Update ft.microvms.instances.mimir-dvm.hostInterface to the NAS NIC name (run `ip link`)
#   4. Add SSH public key(s) to vms/mimir-dvm (services.openssh + root authorizedKeys) for docker-vm access
#   5. Verify ft.diskBtrfs.device below (just deploy will prompt with lsblk output)
#   6. Run ft drives-format for each data/parity/cache drive; commit var/bulk-drives.nix
#   7. Run: just bootstrap mimir <ip>   OR   just bootstrap-local mimir
# =============================================================================
{ ... }:

{
  imports = [
    ./modules
    ../../modules/nixos
  ];

  # --- IDENTITY ---
  networking.hostName = "mimir";
  # var/local/repoPath is a single file shared by every machine's default.nix,
  # but the fleet isn't homogeneous (it currently holds joe's strix checkout
  # path, not the @src convention mimir follows) — see machines/lyra for the
  # same fix. mimir was left unset entirely, silently defaulting to the
  # framework's placeholder and breaking ft.sops.
  ft.repoPath = "/src/ft-home";
  # System-wide (not per-user Home Manager) so `nh os switch` works for any
  # login shell, including admin's — see machines/lyra for the same fix.
  environment.sessionVariables.NH_FLAKE = "/src/ft-home";

  ft.users = {
    mainUser = "admin";
    superUsers = [ "admin" ];
  };
  users.users.admin.initialPassword = "nixos";
  users.mutableUsers = true;

  # SSH — remote administration; NAS is headless
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  networking.firewall.allowedTCPPorts = [ 22 ];

  # --- FEATURE TOGGLES ---

  ft.tailscale = {
    enable = true;
    enableTrayApp = false;
    useRoutingFeatures = "server";
    useSSH = true;
  };

  # Rootful Docker + Komodo microVM, run by reference (guest: vms/mimir-dvm).
  # The tap interface name + MAC are derived from the instance name
  # automatically. hostInterface: update to the actual NIC name once known.
  ft.microvms.instances.mimir-dvm = {
    enable = true;
    vmAddressSuffix = 2;
    hostInterface = ""; # TODO: set after provisioning (e.g. "enp3s0")
  };

  ft.bulkPool = {
    enable = true;
    drivesFile = ./var/bulk-drives.nix;
  };

  ft.sops.enable = true;

  # --- GITOPS (pull-based deploys via comin) ---
  # comin polls this repo and deploys mimir's own nixosConfiguration:
  #   * main          -> `switch` (permanent), and
  #   * testing-mimir -> `test` (ephemeral; reverted on reboot) — the "try it
  #     on mimir first, then promote" lane. See machines/lyra for the same setup.
  # ft-home is a public repo, so the remote is polled anonymously (no
  # tokenSecret, hence no sops credential to provision). signingKeys is
  # intentionally left empty for now — comin will deploy unsigned commits and
  # warn; harden with a trusted GPG key once one is set up.
  ft.gitops = {
    enable = true;
    deployBranch = "main";
    remotes = [
      {
        name = "github";
        url = "https://github.com/track-prepped-68-Corolla/ft-home.git";
      }
    ];
  };

  ft.facter = {
    enable = true;
    reportPath = ./var/facter.json;
  };

  # Both autodetect from ft.facter.reportPath (default true) — no-ops against
  # the current facter.json stub, self-configure once the real nixos-facter
  # report is committed. ft.gpu backs Jellyfin's /dev/dri hardware transcoding
  # in containers/media.yaml; ft.vendorHw covers any board-level RGB/vendor
  # tooling mimir's hardware turns out to need.
  ft.gpu.enable = true;
  ft.vendorHw.enable = true;

  ft.diskBtrfs = {
    enable = true;
    device = "/dev/sda"; # TODO: verify with lsblk on target; just deploy will prompt
    confirmDevice = "/dev/sda"; # must restate device — safety check, see disko-btrfs.nix
  };

  ft.limine.enable = true;

  ft.core.stateVersion = "25.05";
  nixpkgs.hostPlatform = "x86_64-linux";
}
