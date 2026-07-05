# =============================================================================
# brigid — Host Configuration (backup / provisioning laptop)
# =============================================================================
#
# Discovered by the generator at machines/brigid/default.nix and becomes
# nixosConfigurations.brigid.
#
# PURPOSE
#   A secondary machine to provision/back up from, so strix can be wiped and
#   rebuilt to the new standard without losing a working provisioning system.
#   Leaner than strix: no gaming, no 3D modeling, no hardware-specific tuning
#   (GPU/kernel/vendor all autodetect via facter + the autodetecting modules).
#
# NEW STANDARD — STAGED
#   v1 here: ft.diskBtrfs + LUKS (the only wipe-requiring pieces).
#   Layered on post-install once the framework features land (no further wipe):
#     - TPM-backed LUKS unlock  (systemd-cryptenroll adds a keyslot)
#     - TPM-backed Limine Secure Boot
#     - systemd-homed
# =============================================================================
{ lib, pkgs, ... }:

{
  imports = [
    ./modules
    ../../modules/nixos
  ];

  # --- IDENTITY ---
  networking.hostName = "brigid";
  ft.repoPath = lib.strings.trim (builtins.readFile ../../var/local/repoPath);

  ft.users = {
    mainUser = "joe";
    superUsers = [ "joe" ];
    u2f.mappings.joe = "v+e+ZRyIL4d1FLrvbYhngm1tii+MlU2KAxoJd1b6OBNAe+bZ5h6l5ycVBhsOk+Dkm4Npok3XYT0PQtElOpr6hQ==,CRTxD7nPfvMv59eurT72PVdEKDjfx+a8jj8nzzkzd9lrvB/wpepu17QDRfOm5Du2PmR+Uas8glT+/rEStt+sEA==,es256,+presence%";
  };
  users.users.joe.initialPassword = "nixos";
  users.mutableUsers = true;

  # --- DESKTOP / DAILY DRIVER (leaner than strix: no gaming, no 3D) ---
  ft.limine.enable = true;
  ft.cosmicGreeter.enable = true;
  ft.plasma.enable = true;
  services.displayManager.sddm.enable = false;
  ft.gpu.enable = true; # autodetects the GPU vendor from facter.json

  # --- PROVISIONING TOOLCHAIN (brigid's reason to exist) ---
  ft.cli.enable = true; # ft CLI, including colmena
  ft.keepass.enable = true;
  ft.yubikey.enable = true;
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

  # --- KERNEL: stock latest mainline (not the CachyOS kernel strix runs) ---
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  # --- NEW STANDARD: btrfs + LUKS with TPM2+PIN unlock ---
  # Until the TPM keyslot is enrolled post-install, boot falls back to the
  # passphrase keyslot. Enroll once after install:
  #   sudo systemd-cryptenroll --tpm2-device=auto --tpm2-with-pin=yes <luks-partition>
  # device/confirmDevice are rewritten by select-disk.sh during deploy.
  ft.diskBtrfs = {
    enable = true;
    luks = {
      enable = true;
      tpm.enable = true;
    };
    device = "/dev/nvme0n1";
    confirmDevice = "";
  };

  ft.facter = {
    enable = true;
    reportPath = ./var/facter.json; # written by `ft generate-facts brigid <ip>` during deploy
  };

  ft.core.stateVersion = "25.05";
  nixpkgs.hostPlatform = "x86_64-linux";
}
