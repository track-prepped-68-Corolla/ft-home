{ lib, config, inputs, ... }:
let
  cfg = config.ft.hardware.amdAi;
in
{
  # Upstream hardware module — permitted import per style rules.
  imports = [ inputs.nix-amd-ai.nixosModules.default ];

  options.ft.hardware.amdAi = {
    enable = lib.mkEnableOption "AMD NPU/GPU AI stack" // {
      description = "Enables the nix-amd-ai stack on strix halo: XDNA 2 NPU, Vulkan inference, stable-diffusion.cpp image generation, and the Lemonade OpenAI-compatible server.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.amd-ai = {
      isSystemUser = lib.mkDefault true;
      group = lib.mkDefault "amd-ai";
      extraGroups = lib.mkDefault [
        "video"
        "render"
      ];
      home = lib.mkDefault "/var/lib/lemonade";
      createHome = lib.mkDefault true;
    };
    users.groups.amd-ai = { };

    nix.settings = {
      extra-substituters = lib.mkDefault [ "https://nix-amd-ai.cachix.org" ];
      extra-trusted-public-keys = lib.mkDefault [
        "nix-amd-ai.cachix.org-1:F4OU4vw/lV2oiG6SBHZ+nqjl4EFJuqI4X9A7pvaBmhQ="
      ];
    };

    hardware.amd-npu = {
      enable = lib.mkDefault true;
      enableNPU = lib.mkDefault true;
      enableVulkan = lib.mkDefault true;
      enableImageGen = lib.mkDefault true;
      enableLemonade = lib.mkDefault true;
      lemonade.user = lib.mkDefault "amd-ai";
      gpuMemory = {
        ttmSizeGiB = lib.mkDefault 96;
        pagePoolSizeGiB = lib.mkDefault 16;
      };
    };
  };
}
