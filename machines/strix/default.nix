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
{ lib, ... }:

{
  imports = [
    ./modules
    ../../modules/nixos
  ];

  # --- IDENTITY ---
  networking.hostName = "strix";
  ft.repoPath = lib.strings.trim (builtins.readFile ../../var/local/repoPath);

  ft.users = {
    mainUser = "joe";
    superUsers = [ "joe" ];
    u2f.mappings.joe = "v+e+ZRyIL4d1FLrvbYhngm1tii+MlU2KAxoJd1b6OBNAe+bZ5h6l5ycVBhsOk+Dkm4Npok3XYT0PQtElOpr6hQ==,CRTxD7nPfvMv59eurT72PVdEKDjfx+a8jj8nzzkzd9lrvB/wpepu17QDRfOm5Du2PmR+Uas8glT+/rEStt+sEA==,es256,+presence%";
  };
  users.users.joe.initialPassword = "nixos";
  users.mutableUsers = true;

  # --- FEATURE TOGGLES ---
  ft.limine.enable = true;
  ft.cosmicGreeter.enable = true;
  ft.plasma.enable = true;
  services.displayManager.sddm.enable = false;
  ft.mullet = {
    enable = true;
    sourcePath = ../../users/joe/var/mullet;
  };
  ft.gpu.enable = true;
  ft.yubikey.enable = true;
  ft.cli.enable = true;
  ft.keepass.enable = true;
  ft.vendorHw.enable = true;

  # Rootful Docker + Komodo microVM, run by reference (guest: vms/strix-docker,
  # which carries the docker/Komodo config + the docker-vm SSH key).
  ft.microvms.instances.strix-docker = {
    enable = true;
    vmAddressSuffix = 2;
    vmMac = "02:00:00:00:00:01";
    hostInterface = "wlp194s0";
  };

  #  ft.hermesVm = {
  #    enable = true;
  #    vmName = "hermes";
  #    ollamaUrl = "http://10.0.100.1:13305";
  #    hostInterface = "wlp194s0";
  #    sshAuthorizedKeys = [
  #      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIDgZCe1UZA1E7bCpTWz5NUMHlGUq16nOobSJ2LyyZCP2AAAABHNzaDo= track-prepped-68-Corolla@protonmail.com"
  #    ];
  #  };

  ft.ssh = {
    enable = true;
    user = "admin";
    authorizedKeys = [
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIDgZCe1UZA1E7bCpTWz5NUMHlGUq16nOobSJ2LyyZCP2AAAABHNzaDo= track-prepped-68-Corolla@protonmail.com"
    ];
  };

  ft.tailscale = {
    enable = true;
    useSSH = true;
  };

  # sops-nix — prerequisite for the Komodo secrets/GitOps toggles below. Safe on
  # its own: it declares no secrets until a feature that uses one is enabled, so
  # the set of decrypted secrets is unchanged from today. strix's SSH host key is
  # the age recipient (var/secrets/.sops.yaml). useTPM/useYubikey stay off — those
  # recipients are still placeholders/parked.
  ft.sops.enable = true;

  # ── Komodo GitOps [secrets] + auto-apply — DEFERRED ──────────────────────────
  # These were staged on the old inline ft.dockervm.komodo.{peripherySecrets,
  # coreSecrets,autoApply} toggles, which the Phase 2 microVM decoupling retired
  # along with ft.dockervm. The guest is now standalone (vms/strix-docker) and a
  # standalone guest cannot read strix's repoPath-relative sops tree the way the
  # inline guest did, so the secret-injection + host-side auto-apply path needs a
  # decoupled design (framework side) before it can be re-enabled here.

  ft.gaming.enable = true;

  ft.cachyos = {
    enable = true;
    variant = "latest-lto-x86_64-v4";
  };

  ft.flatpak = {
    enable = true;
    frontend.enable = true;
  };

  ft.facter = {
    enable = true;
    reportPath = ./facter.json;
  };

  ft.core.stateVersion = "25.05";
  nixpkgs.hostPlatform = "x86_64-linux";

  # --- AMD NPU/GPU AI STACK ---
  ft.amdAi.enable = true;
}
