# =============================================================================
# strix — Host Configuration
# =============================================================================
#
# Discovered by lib/generator.nix at machines/strix/default.nix
# and becomes nixosConfigurations.strix.
#
# WHAT GOES HERE
#   hardware-configuration.nix   machine-specific kernel modules and filesystems
#   modules/nixos                consumer NixOS modules (auto-gated by ft.*)
#   Identity                     hostName, ft.users.mainUser, ft.users.superUsers
#   ft.* feature toggles         enable framework and consumer modules
#
# WHAT DOES NOT GO HERE
#   Do not import ft-home modules directly — the generator injects them.
#   Per-user Home Manager config belongs in users/<username>/default.nix.
# =============================================================================
{ ... }:

{
  imports = [
    ./modules
    ../../modules/nixos
  ];

  # --- IDENTITY ---
  networking.hostName = "strix";

  ft.users = {
    mainUser = "joe";
    superUsers = [ "joe" ];
    u2f.mappings.joe = "v+e+ZRyIL4d1FLrvbYhngm1tii+MlU2KAxoJd1b6OBNAe+bZ5h6l5ycVBhsOk+Dkm4Npok3XYT0PQtElOpr6hQ==,CRTxD7nPfvMv59eurT72PVdEKDjfx+a8jj8nzzkzd9lrvB/wpepu17QDRfOm5Du2PmR+Uas8glT+/rEStt+sEA==,es256,+presence%";
  };
  users.users.joe.initialPassword = "nixos";
  users.mutableUsers = true;

  # --- FEATURE TOGGLES ---
  ft.boot.limine.enable = true;
  ft.desktop.cosmic.enable = true;
  ft.mullet = {
    enable     = true;
    sourcePath = ../../users/joe/var/mullet.txt;
  };
  ft.hardware.gpu.enable = true;
  ft.hardware.yubikey.enable = true;
  ft.cli.enable = true;
  ft.keepass.enable = true;
  ft.dockervm = {
    enable = true;
    hostInterface = "wlp194s0";
  };

  ft.security.sops = {
    enable = true;
    useTPM = true;
  };

  ft.gaming.enable = true;


  ft.kernel.cachyos = {
    enable = true;
    variant = "latest-lto-x86_64-v4";
  };

  ft.hardware.facter = {
    enable = true;
    reportPath = ./facter.json;
  };

  ft.system.core.stateVersion = "25.05";
  nixpkgs.hostPlatform = "x86_64-linux";

  ft.services.localAi.enable = false;

  # --- AMD NPU/GPU AI STACK ---
  ft.hardware.amdAi.enable = true;
}
