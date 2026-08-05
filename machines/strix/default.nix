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
  ft.noctalia.enable = true;

  # Rootful Docker + Komodo microVM, run by reference (guest: vms/strix-dvm,
  # which carries the docker/Komodo config + the docker-vm SSH key). The tap
  # interface name + MAC are derived from the instance name automatically.
  ft.microvms.instances.strix-dvm = {
    enable = true;
    vmAddressSuffix = 2;
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

  # ── Komodo GitOps [secrets] + auto-apply — STAGED ────────────────────────────
  # The framework now supports secrets on a standalone microVM guest (via
  # ft.vmSecrets on the guest + ft.microvms.instances.<name>.shareSecrets and
  # ft.komodoApply on the host). To enable it on strix's docker VM, provision
  # each secret BEFORE uncommenting — the toggles are split between the guest
  # (vms/strix-dvm) and this host.
  #
  # (1) Guest [secrets] injection into the Stacks Komodo deploys:
  #     a. In vms/strix-dvm/default.nix set `ft.vmSecrets.enable = true;` and,
  #        e.g., `ft.komodo.secrets.periphery.enable = true;`. Deploy once so the
  #        guest boots and generates its persistent ed25519 host key — the sops
  #        age recipient, on the sshkeys volume.
  #     b. Add the guest recipient to var/secrets/.sops.yaml as a creation_rule
  #        for komodo.yaml:   ssh-keyscan <guest-ip> 2>/dev/null | ssh-to-age
  #     c. Create var/secrets/komodo.yaml with the komodo/periphery_secrets key
  #        (a [secrets] TOML), then share the sops tree into the VM from here:
  #  ft.microvms.instances.strix-dvm.shareSecrets = true;
  #
  # (2) Auto-reconcile Komodo with containers/ on every `ft switch`:
  #     a. Komodo -> Settings -> API Keys -> create a key.
  #     b. Add komodo/api_env to var/secrets/secrets.yaml:
  #          KOMODO_API_KEY=K-...   KOMODO_API_SECRET=S-...
  #     c. Generate + commit the sync manifest:  ft komodo-sync (run on strix so
  #        the git remote resolves to the real GitHub URL). Then uncomment:
  #  ft.komodoApply.strix-dvm.enable = true;

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
    reportPath = ./var/facter.json;
  };

  ft.core.stateVersion = "25.05";
  nixpkgs.hostPlatform = "x86_64-linux";

  # --- AMD NPU/GPU AI STACK ---
  ft.amdAi.enable = true;
  ft.claudeCode = {
    enable = true;
    model = "Qwen3.6-35B-A3B-GGUF";
  };
}
