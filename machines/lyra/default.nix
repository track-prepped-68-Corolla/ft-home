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
{ ... }:

let
  # var/local/repoPath is a single file shared by every machine's default.nix,
  # but the fleet isn't homogeneous: it currently holds joe's strix checkout
  # path (/home/joe/git/ft-home), which strix's own ft.cli setup depends on.
  # lyra has no joe user and follows the @src convention (see ft.diskBtrfs /
  # disko-btrfs.nix), so it needs its own value rather than reading that file.
  repoPath = "/src/ft-home";
in
{
  imports = [
    ./modules
    ../../modules/nixos
  ];

  # --- IDENTITY ---
  networking.hostName = "lyra";
  ft.repoPath = repoPath;
  # System-wide (not per-user Home Manager) so `nh os switch`/`nh home switch`
  # work for any login shell, including admin's, without requiring a Home
  # Manager profile to have been activated first.
  environment.sessionVariables.NH_FLAKE = repoPath;

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
  ft.tailscale = {
    enable = true;
    useSSH = true;
  };
  # The ft CLI helper (just-recipe wrapper) — was never enabled here, unlike
  # strix/brigid/template, so the `ft` command didn't exist on lyra at all.
  ft.cli.enable = true;
  # System Flatpak service + Flathub remote. Discover is enabled as the GUI
  # frontend since ft.plasma is active; the media user's per-user Flatpak
  # list (RetroDECK) lives in users/media.
  ft.flatpak = {
    enable = true;
    frontend.enable = true;
  };
  # sops via the SSH host key (&lyra) only for now. TPM enrollment was never
  # completed (&lyra_tpm in .sops.yaml is still a placeholder), and useTPM
  # requires /var/lib/sops-nix/key.txt to exist unconditionally once set —
  # with no TPM identity enrolled, that file never materializes and
  # sops-install-secrets fails outright even though the SSH host key alone is
  # sufficient. Re-enable once TPM enrollment is actually done: generate the
  # sealed key via age-plugin-tpm, put the real pubkey into .sops.yaml's
  # &lyra_tpm, run sops updatekeys, then flip this back on.
  ft.sops = {
    enable = true;
    useTPM = false;
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
    device = "/dev/disk/by-id/nvme-TWSC_TSC3AN512-F1Q20S_TTSMA264FX01438";
    confirmDevice = "/dev/disk/by-id/nvme-TWSC_TSC3AN512-F1Q20S_TTSMA264FX01438";
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
