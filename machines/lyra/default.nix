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
#   3. Run `ft generate-facts lyra <ip>` to commit machines/lyra/var/facter.json
#      (ft.facter is already wired below — it no-ops until that file exists)
#   4. Populate ft.ssh.authorizedKeys with your public key(s)
#   5. Derive this host's age recipient (ssh-to-age) and replace the &lyra
#      placeholder in var/secrets/.sops.yaml
#   6. Run nixos-anywhere pointing at ft-home#lyra
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
  # admin is always created by ft.admin as the wheel/SSH management account
  # (ft.users filters it out of its own user lists). media is an unprivileged
  # autologin user for the TV-facing session.
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

  # Hardware report. Wired ahead of time so `ft generate-facts lyra <ip>` is the
  # only step needed — the facter module no-ops until var/facter.json exists
  # (guarded by pathExists), so this evaluates cleanly before the file is there.
  ft.facter = {
    enable = true;
    reportPath = ./var/facter.json;
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
