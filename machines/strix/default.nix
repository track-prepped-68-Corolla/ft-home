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
#   Identity                     hostName, ft.user.mainUser, ft.user.superUsers
#   ft.* feature toggles         enable framework and consumer modules
#
# WHAT DOES NOT GO HERE
#   Do not import ft-home modules directly — the generator injects them.
#   Per-user Home Manager config belongs in users/<username>/default.nix.
# =============================================================================
{ inputs, ... }:

{
  imports = [
    inputs.stylix.nixosModules.stylix
    inputs.sops-nix.nixosModules.sops
    ./modules
    ../../modules/nixos
  ];

  # --- IDENTITY ---
  networking.hostName = "strix";

  ft.user = {
    mainUser = "joe";
    superUsers = [ "joe" ];
    u2f.mappings.joe = "v+e+ZRyIL4d1FLrvbYhngm1tii+MlU2KAxoJd1b6OBNAe+bZ5h6l5ycVBhsOk+Dkm4Npok3XYT0PQtElOpr6hQ==,CRTxD7nPfvMv59eurT72PVdEKDjfx+a8jj8nzzkzd9lrvB/wpepu17QDRfOm5Du2PmR+Uas8glT+/rEStt+sEA==,es256,+presence%";
  };
  users.users.joe.initialPassword = "nixos";
  users.mutableUsers = true;

  # --- FEATURE TOGGLES ---
  ft.limine.enable = true;
  ft.cosmic.enable = true;
  ft.mullet = {
    enable = true;
    sourcePath = ../../users/joe/var/mullet.txt;
  };
  ft.gpu.enable = true;
  ft.yubikey.enable = true;
  ft.just.enable = true;
  ft.keepass.enable = true;

  ft.sops = {
    enable = true;
    useTPM = true;
  };

  ft.kernel = {
    enable = true;
    variant = "latest-lto-x86_64-v4";
  };

  ft.facter = {
    enable = true;
    reportPath = ./facter.json;
  };

  ft.core.stateVersion = "25.05";
  nixpkgs.hostPlatform = "x86_64-linux";

  # --- LOCAL AI STACK ---
  # Uncomment and fill in your actual paths to enable: llamafile → Hermes → AnythingLLM
  # Requires: hermes-agent installed for joe (pip install --user hermes-agent)
  # After first boot, open http://localhost:3001 and configure LLM provider:
  #   Generic OpenAI → Base URL: http://localhost:9119/v1 → API key: local
  #
  ft."local-ai" = {
    enable = true;
    user = "joe";
    llamafile = {
      execPath = "/home/joe/Documents/llamafile-0.10.1-thin";
      modelPath = "/home/joe/Documents/Qwen3.5-27B.Q6_K.gguf";
      extraArgs = [
        "--ctx-size"
        "32768"
        "--n-gpu-layers"
        "--server"
        "99"
      ];
    };
  };
}
