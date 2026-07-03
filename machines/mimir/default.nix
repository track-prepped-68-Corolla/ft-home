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
#   3. Update ft.dockervm.hostInterface to the NAS NIC name (run `ip link`)
#   4. Add SSH public key(s) to ft.dockervm.sshAuthorizedKeys for docker-vm access
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
  };

  # MicroVM with rootful Docker Compose + Komodo container management.
  # hostInterface: update to the actual NIC name once hardware is known.
  ft.dockervm = {
    enable = true;
    hostInterface = ""; # TODO: set after provisioning (e.g. "enp3s0")
    sshAuthorizedKeys = [ ]; # TODO: add admin SSH public key(s) for docker-vm access
  };

  ft.bulkPool = {
    enable = true;
    drivesFile = ./var/bulk-drives.nix;
  };

  ft.sops.enable = true;

  ft.facter = {
    enable = true;
    reportPath = ./var/facter.json;
  };

  ft.diskBtrfs = {
    enable = true;
    device = "/dev/sda"; # TODO: verify with lsblk on target; just deploy will prompt
    confirmDevice = "/dev/sda"; # must restate device — safety check, see disko-btrfs.nix
  };

  ft.limine.enable = true;

  ft.core.stateVersion = "25.05";
  nixpkgs.hostPlatform = "x86_64-linux";
}
