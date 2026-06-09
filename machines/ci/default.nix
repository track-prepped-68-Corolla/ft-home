# =============================================================================
# ci — GitHub Actions stub machine
# =============================================================================
#
# Exists solely so that CI evaluation can resolve ft.repoPath via
# machines/ci/var/repoPath without reading /etc/hostname from a runner
# with an unknown hostname. The CI workflow forces `hostname ci` before
# any nix invocations.
#
# This machine is never provisioned or booted.
# =============================================================================
{ ... }:

{
  networking.hostName = "ci";

  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [
      "defaults"
      "size=2G"
      "mode=755"
    ];
  };

  boot.loader.systemd-boot.enable = true;

  ft.core.stateVersion = "25.05";
  nixpkgs.hostPlatform = "x86_64-linux";
}
