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
#   4. Generate WireGuard keypair; encrypt private key with sops-nix;
#      set ft.sops.enable = true and uncomment wg0.privateKeyFile
#   5. Replace wg0 peer placeholders (publicKey, endpoint, address, allowedIPs)
#   6. Populate ft.ssh.authorizedKeys with your public key(s)
#   7. Run nixos-anywhere pointing at nixos-config#lyra
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

  # --- WIREGUARD CLIENT (scaffold) ---
  # wg0 will not come up until privateKeyFile is set and peer values are filled.
  # After provisioning:
  #   1. Run: wg genkey | sops-nix encrypt → var/secrets/wireguard/lyra.age
  #   2. Set ft.sops.enable = true
  #   3. Uncomment privateKeyFile below
  #   4. Replace address, publicKey, endpoint, and allowedIPs
  networking.wg-quick.interfaces.wg0 = {
    # privateKeyFile = config.sops.secrets."wireguard/lyra/privateKey".path;
    address = [ "TODO_LYRA_WG_IP/24" ];
    peers = [
      {
        publicKey = "TODO_SERVER_PUBKEY=";
        endpoint = "TODO_SERVER_HOST:51820";
        allowedIPs = [ "TODO_ALLOWED_SUBNET" ];
        persistentKeepalive = 25;
      }
    ];
  };

  ft.core.stateVersion = "25.05";
  nixpkgs.hostPlatform = "x86_64-linux";
}
