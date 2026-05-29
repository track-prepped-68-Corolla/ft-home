# =============================================================================
# strix-vm — VM Test Configuration
# =============================================================================
#
# Inherits the full strix config and disables the features that don't work
# in a QEMU VM. Build and run with:
#
#   nix build .#nixosConfigurations.strix-vm.config.system.build.vm
#   ./result/bin/run-strix-vm
#
# SSH into the running VM (from the host):
#   ssh -p 2222 joe@localhost
# =============================================================================
{ lib, ... }:

{
  imports = [ ../strix/default.nix ];

  networking.hostName = lib.mkForce "strix-vm";

  # CachyOS kernel requires either the nix-cachyos binary cache or an hours-long
  # build from source. Use the default kernel for VM testing.
  ft.kernel.cachyos.enable = lib.mkForce false;

  # No TPM or age key file available in QEMU — sops activation would stall.
  ft.security.sops.enable = lib.mkForce false;

  # No physical YubiKey in the VM. ft-home's user.nix also unconditionally
  # enables PAM U2F, so force it off to unblock login and sudo.
  ft.hardware.yubikey.enable = lib.mkForce false;
  security.pam.u2f.enable = lib.mkForce false;

  # llamafile / model paths don't exist inside the VM image.
  ft."local-ai".enable = lib.mkForce false;
}
