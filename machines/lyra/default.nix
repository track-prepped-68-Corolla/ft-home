# =============================================================================
# lyra — Media PC Host Configuration
# =============================================================================
#
# Discovered by lib/generator.nix at machines/lyra/default.nix
# and becomes nixosConfigurations.lyra.
#
# PROVISIONING CHECKLIST
#   1. Boot target into NixOS live environment
#   2. Run `lsblk` and update ft.diskBtrfs.device if not /dev/nvme0n1
#   3. Run nixos-facter; commit output to machines/lyra/var/facter.json
#   4. Add ft.facter block once facter.json is committed
#   5. Populate ft.ssh.authorizedKeys with your public key(s)
#   6. Derive this host's age recipient (ssh-to-age) and replace the &lyra
#      placeholder in var/secrets/.sops.yaml
#   7. Run nixos-anywhere pointing at ft-home#lyra
#      tailscale auto-joins on first boot via ft.tailscale.autoJoin — no
#      manual `tailscale up` needed once var/secrets/secrets.yaml carries a
#      valid tailscale/authkey
# =============================================================================
{ lib, pkgs, ... }:

{
  imports = [
    ./modules
    ../../modules/nixos
  ];

  # --- IDENTITY ---
  networking.hostName = "lyra";
  ft.repoPath = lib.strings.trim (builtins.readFile ../../var/local/repoPath);

  # --- USERS ---
  # admin is always created by ft.users as the wheel/SSH management account.
  # media is an unprivileged autologin user for the TV-facing session.
  ft.users = {
    mainUser = "admin";
    normalUsers = [ "media" ];
  };
  users.users.admin.initialPassword = "nixos";
  users.users.media = {
    initialPassword = "nixos";
    extraGroups = [ "input" ];
  };
  users.mutableUsers = true;

  # --- DISPLAY MANAGER ---
  services.displayManager.sddm.enable = true;
  services.displayManager.autoLogin = {
    enable = true;
    user = "media";
  };

  # --- FEATURE TOGGLES ---
  ft.limine.enable = true;
  ft.plasma.enable = true;
  ft.gaming.enable = true;
  ft.gpu.enable = true;
  ft.tailscale.enable = true;
  ft.sops.enable = true;

  ft.diskBtrfs = {
    enable = true;
    # TODO: verify with `lsblk` on target — update if not NVMe
    device = "/dev/nvme0n1";
  };

  ft.ssh = {
    enable = true;
    user = "admin";
    authorizedKeys = [
      # TODO: add your SSH public key(s)
    ];
  };

  # --- HDMI CEC (AMD iGPU via amdgpu DRM CEC connector) ---
  boot.kernelModules = [ "cec" ];
  environment.systemPackages = with pkgs; [
    libcec
    v4l-utils
  ];

  ft.core.stateVersion = "25.05";
  nixpkgs.hostPlatform = "x86_64-linux";
}
