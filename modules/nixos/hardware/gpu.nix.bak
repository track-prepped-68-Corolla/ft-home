{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# UNIVERSAL GPU MODULE
# ------------------------------------------------------------------------------
# This module provides a consolidated and flexible configuration for various
# GPU setups, including NVIDIA (proprietary/open), AMD, and Intel integrated
# graphics, along with PRIME offloading for hybrid graphics systems.
# The goal is to offer a single, unified interface for GPU configuration.
################################################################################

let
  cfg = config.ft.hardware.gpu;

  # Helper function to check if a specific GPU vendor is enabled.
  isNvidia = cfg.vendor == "nvidia";
  isAmd = cfg.vendor == "amd";
  isIntel = cfg.vendor == "intel";

in
{
  options.ft.hardware.gpu = {
    enable = lib.mkEnableOption "Universal GPU Configuration";

    # Primary GPU vendor (e.g., "nvidia", "amd", "intel").
    vendor = lib.mkOption {
      type = lib.types.enum [
        "nvidia"
        "amd"
        "intel"
      ];
      default = "amd";
      description = "Primary GPU vendor (nvidia, amd, or intel).";
    };

    # Enable 32-bit support for compatibility with older games/applications.
    enable32Bit = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable 32-bit graphics support.";
    };

    # NVIDIA Specific Options
    nvidia = {
      # Use the open-source (GPL) NVIDIA kernel modules. Recommended for Turing+.
      openKernelModules = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Use open-source NVIDIA kernel modules (Turing+). Set to false for older cards.";
      };
      # Choose NVIDIA driver package (e.g., "stable", "beta").
      driverPackage = lib.mkOption {
        type = lib.types.enum [
          "stable"
          "beta"
        ];
        default = "beta";
        description = "NVIDIA driver package to use (stable or beta).";
      };
      # Enable NVIDIA Settings GUI tool.
      enableSettings = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable nvidia-settings GUI.";
      };
      # Enable NVIDIA power management.
      enablePowerManagement = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable NVIDIA power management.";
      };
      # Enable fine-grained power management (D3cold) for laptops/hybrid systems.
      finegrainedPowerManagement = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable fine-grained NVIDIA power management (D3cold).";
      };
    };

    # PRIME Offloading (for hybrid graphics, e.g., iGPU + dGPU)
    prime = {
      enable = lib.mkEnableOption "PRIME GPU offloading (for hybrid graphics)";

      # Bus ID of the GPU connected to the display (usually the iGPU).
      primaryBusId = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "PCI:35:0:0";
        description = "Bus ID of the GPU connected to the display (e.g., iGPU). Run 'lspci -nnk' to find.";
      };

      # Bus ID of the discrete GPU (e.g., NVIDIA dGPU).
      secondaryBusId = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "PCI:45:0:0";
        description = "Bus ID of the discrete GPU. Run 'lspci -nnk' to find.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.graphics.enable = true;
    hardware.graphics.enable32Bit = cfg.enable32Bit;

    # --------------------------------------------------------------------------
    # NVIDIA Configuration
    # --------------------------------------------------------------------------
    services.xserver.videoDrivers =
      lib.mkIf isNvidia [
        "nvidia"
      ]
      ++ lib.mkIf isAmd [
        "amdgpu"
      ]
      ++ lib.mkIf isIntel [
        "intel"
      ];

    hardware.nvidia = lib.mkIf isNvidia {
      modesetting.enable = true;
      open = cfg.nvidia.openKernelModules;
      nvidiaSettings = cfg.nvidia.enableSettings;
      powerManagement = {
        enable = cfg.nvidia.enablePowerManagement;
        finegrained = cfg.nvidia.finegrainedPowerManagement;
      };
      package =
        if cfg.nvidia.driverPackage == "beta" then
          config.boot.kernelPackages.nvidiaPackages.beta
        else
          config.boot.kernelPackages.nvidiaPackages.stable;
    };

    # --------------------------------------------------------------------------
    # PRIME Offloading Configuration (for hybrid graphics)
    # --------------------------------------------------------------------------
    hardware.nvidia.prime = lib.mkIf (isNvidia && cfg.prime.enable) {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      nvidiaBusId = cfg.prime.secondaryBusId;
      amdgpuBusId = lib.mkIf (cfg.vendor == "amd") cfg.prime.primaryBusId; # Use if iGPU is AMD
      intelBusId = lib.mkIf (cfg.vendor == "intel") cfg.prime.primaryBusId; # Use if iGPU is Intel
    };

    # --------------------------------------------------------------------------
    # AMD Specific Enhancements
    # --------------------------------------------------------------------------
    hardware.amdgpu.amdvlk.enable = lib.mkIf (isAmd && config.hardware.opengl.enable) true;
    hardware.amdgpu.opencl.enable = lib.mkIf (isAmd && config.hardware.opengl.enable) true;

    # --------------------------------------------------------------------------
    # Intel Specific Enhancements
    # --------------------------------------------------------------------------
    hardware.intel.enable = lib.mkIf isIntel true;
    hardware.intel.enableEarlyKms = lib.mkIf isIntel true;

    # For any GPU type, ensure basic OpenGL and Vulkan support is enabled
    hardware.opengl.enable = true;
    hardware.opengl.dri.driver = lib.mkIf isAmd "radeonsi"; # For AMD
    hardware.opengl.dri.driver = lib.mkIf isIntel "i965"; # For Intel

    # Ensure the main user is in the 'render' and 'video' groups for GPU access.
    users.users.${config.mainuser or "joe"}.extraGroups =
      lib.mkIf cfg.enable [
        "render"
        "video"
      ]
      ++ lib.mkIf (isNvidia && cfg.nvidia.enable) [
        "nvidia_modeset"
        "nvidia_uvm"
        "nvidia_runtime"
      ];
  };
}
