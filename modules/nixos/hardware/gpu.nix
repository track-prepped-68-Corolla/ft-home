{
  config,
  lib,
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

  facterPath = config.ft.hardware.facter.reportPath;

  facter =
    if cfg.autodetect && facterPath != null && builtins.pathExists facterPath then
      builtins.fromJSON (builtins.readFile facterPath)
    else
      { };

  gpuCards = facter.hardware.graphics_card or [ ];
  primaryGpu = if gpuCards != [ ] then builtins.head gpuCards else { };
  driverName = lib.toLower (primaryGpu.driver or "");
  vendorHex = lib.toLower ((primaryGpu.vendor or { }).hex or "");

  detectedVendor =
    if !cfg.autodetect then
      null
    else if driverName == "amdgpu" || driverName == "radeon" || vendorHex == "1002" then
      "amd"
    else if driverName == "nvidia" || vendorHex == "10de" then
      "nvidia"
    else if driverName == "i915" || driverName == "xe" || vendorHex == "8086" then
      "intel"
    else
      null;

  effectiveVendor = if detectedVendor != null then detectedVendor else cfg.vendor;

  isNvidia = effectiveVendor == "nvidia";
  isAmd = effectiveVendor == "amd";
  isIntel = effectiveVendor == "intel";

in
{
  options.ft.hardware.gpu = {
    enable = lib.mkEnableOption "Universal GPU Configuration";

    autodetect = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Detect GPU vendor from ft.hardware.facter.reportPath. When true and a known GPU is found, overrides the vendor option default. Set to false to use the vendor option directly.";
    };

    # Primary GPU vendor (e.g., "nvidia", "amd", "intel").
    vendor = lib.mkOption {
      type = lib.types.enum [
        "nvidia"
        "amd"
        "intel"
      ];
      default = "amd";
      description = "Primary GPU vendor (nvidia, amd, or intel). Ignored when autodetect = true and a known GPU is found in facter.json.";
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

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        hardware.graphics = {
          enable = true;
          inherit (cfg) enable32Bit;
        };

        services.xserver.videoDrivers =
          lib.optional isNvidia "nvidia" ++ lib.optional isAmd "amdgpu" ++ lib.optional isIntel "intel";

        users.users.${config.ft.users.mainUser}.extraGroups = [
          "render"
          "video"
        ];
      }

      # --------------------------------------------------------------------------
      # NVIDIA Configuration
      # --------------------------------------------------------------------------
      (lib.mkIf isNvidia {
        hardware.nvidia = lib.mkMerge [
          {
            modesetting.enable = true;
            open = cfg.nvidia.openKernelModules;
            nvidiaSettings = cfg.nvidia.enableSettings;
            powerManagement.enable = cfg.nvidia.enablePowerManagement;
            powerManagement.finegrained = cfg.nvidia.finegrainedPowerManagement;
            package =
              if cfg.nvidia.driverPackage == "beta" then
                config.boot.kernelPackages.nvidiaPackages.beta
              else
                config.boot.kernelPackages.nvidiaPackages.stable;
          }
          # PRIME Offloading (for hybrid graphics)
          (lib.mkIf cfg.prime.enable {
            prime.offload.enable = true;
            prime.offload.enableOffloadCmd = true;
            prime.nvidiaBusId = cfg.prime.secondaryBusId;
            prime.amdgpuBusId = lib.mkIf isAmd cfg.prime.primaryBusId;
            prime.intelBusId = lib.mkIf isIntel cfg.prime.primaryBusId;
          })
        ];
      })

      # --------------------------------------------------------------------------
      # AMD Specific Enhancements
      # --------------------------------------------------------------------------
      (lib.mkIf isAmd {
        hardware.amdgpu.opencl.enable = true;
      })
    ]
  );
}
