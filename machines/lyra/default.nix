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
{ lib, ... }:

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
  # media is a kiosk autologin user — no password (login is autologin-only) and
  # no screen lock (see users/media: kscreenlocker disabled), so the TV session
  # never demands credentials. admin remains the recoverable account.
  users.users.media = {
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
  ft.plasmaBigscreen = {
    enable = true;
    defaultSession = true;
  };
  ft.gaming.enable = true;
  # ft.jovian provides its own gamescope wrapper for the Big Picture
  # session; ft.gaming's standalone wrapper conflicts with it on
  # security.wrappers.gamescope.source.
  ft.gaming.gamescope.enable = false;
  ft.gpu.enable = true;
  ft.tailscale.enable = true;
  # sops via the SSH host key (&lyra), plus a TPM-sealed age identity for
  # decryption (age-plugin-tpm). Register lyra's TPM recipient in .sops.yaml
  # (&lyra_tpm) and run `sops updatekeys` before relying on TPM decryption.
  ft.sops = {
    enable = true;
    useTPM = true;
  };

  # --- GITOPS (pull-based deploys via comin) ---
  # comin polls this repo and deploys lyra's own nixosConfiguration:
  #   * main           -> `switch` (permanent), and
  #   * testing-lyra    -> `test` (ephemeral; reverted on reboot) — the "try it on
  #     lyra first, then promote" lane.
  # ft-home is a public repo, so the remote is polled anonymously (no tokenSecret,
  # hence no sops credential to provision). signingKeys is intentionally left empty
  # for now — comin will deploy unsigned commits and warn; harden with a trusted
  # GPG key once one is set up. NOTE: comin only converges lyra once this config
  # (with ft.gitops) is present on `main`; until then it has nothing to deploy.
  ft.gitops = {
    enable = true;
    deployBranch = "main";
    remotes = [
      {
        name = "github";
        url = "https://github.com/track-prepped-68-Corolla/ft-home.git";
      }
    ];
  };

  ft.diskBtrfs = {
    enable = true;
    # TODO: verify with `lsblk` on target — update if not NVMe
    device = "/dev/nvme0n1";
    confirmDevice = "/dev/nvme0n1";
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
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIDgZCe1UZA1E7bCpTWz5NUMHlGUq16nOobSJ2LyyZCP2AAAABHNzaDo= track-prepped-68-Corolla@protonmail.com"
    ];
  };

  # HDMI-CEC (AMD iGPU via amdgpu DRM CEC connector) is provided by
  # ft.plasmaBigscreen.cecSupport (default true) for TV remote input.

  ft.core.stateVersion = "25.05";
  nixpkgs.hostPlatform = "x86_64-linux";

  # --- GAMESCOPE SESSION ---
  # Selectable from SDDM alongside plasma-bigscreen-wayland (the default);
  # autoStart is left at its default false so it doesn't fight Bigscreen for
  # services.displayManager.defaultSession.
  ft.jovian.enable = true;
}
