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
#   Identity                     hostName, mainuser, superUsers
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

  # mainuser is read by user.nix, sops.nix, gaming.nix, virt.nix, and others.
  mainuser = "joe";
  superUsers = [ "joe" ];
  users.users.joe.initialPassword = "nixos";
  users.mutableUsers = true;

  # --- FEATURE TOGGLES ---
  ft.boot.limine.enable = true;
  ft.desktop.cosmic.enable = true;
  ft.mullet.enable = true;
  ft.hardware.gpu.enable = true;
  ft.hardware.yubikey.enable = true;
  ft.cli.enable = true;
  ft.keepass.enable = true;

  ft.security.sops = {
    enable = true;
    useTPM = true;
  };

  ft.kernel.cachyos = {
    enable = true;
    variant = "bore";
  };

  ft.hardware.facter = {
    enable = true;
    reportPath = ./facter.json;
  };

  # U2F key pre-registered. Activate hardware auth by also setting
  # ft.hardware.yubikey.enable = true when the key is physically present.
  ft.hardware.yubikey.u2fMapping = "joe:v+e+ZRyIL4d1FLrvbYhngm1tii+MlU2KAxoJd1b6OBNAe+bZ5h6l5ycVBhsOk+Dkm4Npok3XYT0PQtElOpr6hQ==,CRTxD7nPfvMv59eurT72PVdEKDjfx+a8jj8nzzkzd9lrvB/wpepu17QDRfOm5Du2PmR+Uas8glT+/rEStt+sEA==,es256,+presence%";

  nixpkgs.hostPlatform = "x86_64-linux";

  # --- LOCAL AI STACK ---
  # Uncomment and fill in your actual paths to enable: llamafile → Hermes → AnythingLLM
  # Requires: hermes-agent installed for joe (pip install --user hermes-agent)
  # After first boot, open http://localhost:3001 and configure LLM provider:
  #   Generic OpenAI → Base URL: http://localhost:9119/v1 → API key: local
  #
  ft.services.localAi = {
    enable = true;
    llamafile.execPath = "/home/joe/Documents/llamafile-0.10.1-thin";
    llamafile.modelPath = "/home/joe/Documents/Qwen3.5-27B.Q6_K.gguf";
    # Optional: GPU offload and context size
    llamafile.extraArgs = [
      "--ctx-size"
      "32768"
      "--n-gpu-layers"
      "--server"
      "99"
    ];
  };
}
