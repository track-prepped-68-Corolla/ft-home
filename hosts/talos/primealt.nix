{ config, pkgs, lib, ... }:

{
  options.modules.hardware.nvidia = {
    enable = lib.mkEnableOption "NVIDIA proprietary drivers and optimizations";
  };

  config = lib.mkIf config.modules.hardware.nvidia.enable {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    services.xserver.videoDrivers = [ "amdgpu" "nvidia" ];

    hardware.nvidia = {
      modesetting.enable = true;
      open = true; # Correct for RTX 3090
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.beta;

      # PRIME Configuration
      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        # Ensure these are the DECIMAL values of your Hex Bus IDs
        amdgpuBusId = "PCI:35:0:0"; 
        nvidiaBusId = "PCI:45:0:0";
      };

      powerManagement = {
        enable = true; 
        finegrained = true; # Supported by 3090 to save power
      };
    };

    # Essential for Jovian Game Mode to see the NVIDIA environment
    jovian.steam.extraEnv = {
      "__NV_PRIME_RENDER_OFFLOAD" = "1";
      "__VK_LAYER_NV_optimus" = "NVIDIA_only";
      "__GLX_VENDOR_LIBRARY_NAME" = "nvidia";
    };
  };
}
