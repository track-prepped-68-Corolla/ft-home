# =============================================================================
# lyra — Media PC Host Configuration
# =============================================================================
#
# Discovered by lib/generator.nix at machines/lyra/default.nix
# and becomes nixosConfigurations.lyra.
#
# PROVISIONING CHECKLIST
#   1. Boot target into NixOS live environment
#   2. Run nixos-facter; commit output to machines/lyra/var/facter.json
#   3. Add ft.facter block once facter.json is committed
#   4. Populate ft.ssh.authorizedKeys with your public key(s)
#   5. Run nixos-anywhere pointing at nixos-config#lyra
#   6. Run `sudo tailscale up` to authenticate on first boot
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
