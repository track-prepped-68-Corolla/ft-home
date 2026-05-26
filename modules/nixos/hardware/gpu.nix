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

  # Per-card vendor predicates used for both single-GPU and Optimus detection.
  isNvidiaCard =
    c:
    let
      d = lib.toLower (c.driver or "");
      v = lib.toLower ((c.vendor or { }).hex or "");
    in
    d == "nvidia" || d == "nouveau" || v == "10de";

  isAmdCard =
    c:
    let
      d = lib.toLower (c.driver or "");
      v = lib.toLower ((c.vendor or { }).hex or "");
    in
    d == "amdgpu" || d == "radeon" || v == "1002";

  isIntelCard =
    c:
    let
      d = lib.toLower (c.driver or "");
      v = lib.toLower ((c.vendor or { }).hex or "");
    in
    d == "i915" || d == "xe" || v == "8086";

  nvidiaCards = builtins.filter isNvidiaCard gpuCards;
  igpuCards = builtins.filter (c: isAmdCard c || isIntelCard c) gpuCards;

  # Optimus: one NVIDIA dGPU alongside at least one AMD/Intel iGPU.
  isOptimus = cfg.autodetect && nvidiaCards != [ ] && igpuCards != [ ];

  optNvidiaCard = if nvidiaCards != [ ] then builtins.head nvidiaCards else { };
  optIgpuCard = if igpuCards != [ ] then builtins.head igpuCards else { };

  primaryGpu = if gpuCards != [ ] then builtins.head gpuCards else { };

  detectedVendor =
    if !cfg.autodetect then
      null
    else if isOptimus then
      "nvidia"
    else if isNvidiaCard primaryGpu then
      "nvidia"
    else if isAmdCard primaryGpu then
      "amd"
    else if isIntelCard primaryGpu then
      "intel"
    else
      null;

  effectiveVendor = if detectedVendor != null then detectedVendor else cfg.vendor;

  isNvidia = effectiveVendor == "nvidia";
  isAmd = effectiveVendor == "amd";
  isIntel = effectiveVendor == "intel";

  # Convert a facter sysfs_bus_id ("0000:c4:00.0") to PRIME format ("PCI:196:0:0").
  hexToInt =
    let
      digits = {
        "0" = 0;
        "1" = 1;
        "2" = 2;
        "3" = 3;
        "4" = 4;
        "5" = 5;
        "6" = 6;
        "7" = 7;
        "8" = 8;
        "9" = 9;
        "a" = 10;
        "b" = 11;
        "c" = 12;
        "d" = 13;
        "e" = 14;
        "f" = 15;
      };
    in
    hex: lib.foldl (acc: c: acc * 16 + digits.${c}) 0 (lib.stringToCharacters (lib.toLower hex));

  # Turing (0x1E00+) is the first NVIDIA architecture with open kernel module support.
  nvDeviceId = hexToInt (lib.toLower ((optNvidiaCard.device or { }).hex or "0"));
  nvidiaTuringOrNewer = cfg.autodetect && isNvidia && nvDeviceId >= 7680;
  effectiveOpenKernelModules = if nvidiaTuringOrNewer then true else cfg.nvidia.openKernelModules;

  sysfsIdToPrime =
    id:
    let
      parts = builtins.filter builtins.isString (builtins.split ":" id);
      devFunc = builtins.filter builtins.isString (builtins.split "[.]" (builtins.elemAt parts 2));
    in
    "PCI:${toString (hexToInt (builtins.elemAt parts 1))}:${toString (hexToInt (builtins.elemAt devFunc 0))}:${toString (hexToInt (builtins.elemAt devFunc 1))}";

  # Effective PRIME config: autodetected values fill in when bus IDs are not set manually.
  # Both sysfs_bus_id fields must be present before autodetect enables PRIME; otherwise
  # PRIME would be activated with empty bus IDs which causes an evaluation error.
  optimusHasBusIds = optIgpuCard ? sysfs_bus_id && optNvidiaCard ? sysfs_bus_id;
  effectivePrimeEnable = (isOptimus && optimusHasBusIds) || cfg.prime.enable;

  effectivePrimePrimaryBusId =
    if isOptimus && optimusHasBusIds && cfg.prime.primaryBusId == "" then
      sysfsIdToPrime optIgpuCard.sysfs_bus_id
    else
      cfg.prime.primaryBusId;

  effectivePrimeSecondaryBusId =
    if isOptimus && optimusHasBusIds && cfg.prime.secondaryBusId == "" then
      sysfsIdToPrime optNvidiaCard.sysfs_bus_id
    else
      cfg.prime.secondaryBusId;

  # In Optimus mode the iGPU type is taken from the detected card; in manual mode
  # it falls back to the main vendor (which the user would set to "amd"/"intel").
  effectivePrimeIsIgpuAmd = if isOptimus then isAmdCard optIgpuCard else isAmd;
  effectivePrimeIsIgpuIntel = if isOptimus then isIntelCard optIgpuCard else isIntel;

in
{
  options.ft.hardware.gpu = {
    enable = lib.mkEnableOption "Universal GPU Configuration";

    autodetect = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Detect GPU vendor and Optimus configuration from ft.hardware.facter.reportPath. When true, sets ft.hardware.gpu.vendor and configures PRIME offloading automatically for Optimus setups. Set to false to use the vendor and prime options directly.";
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
        description = "Use open-source NVIDIA kernel modules (Turing+). When autodetect = true this is set automatically based on the GPU device ID; set autodetect = false to override.";
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
        description = "Bus ID of the GPU connected to the display (e.g., iGPU). Derived automatically from facter.json when autodetect = true and an Optimus setup is detected; set explicitly to override.";
      };

      # Bus ID of the discrete GPU (e.g., NVIDIA dGPU).
      secondaryBusId = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "PCI:45:0:0";
        description = "Bus ID of the discrete GPU. Derived automatically from facter.json when autodetect = true and an Optimus setup is detected; set explicitly to override.";
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
            open = effectiveOpenKernelModules;
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
          (lib.mkIf effectivePrimeEnable {
            prime.offload.enable = true;
            prime.offload.enableOffloadCmd = true;
            prime.nvidiaBusId = effectivePrimeSecondaryBusId;
            prime.amdgpuBusId = lib.mkIf effectivePrimeIsIgpuAmd effectivePrimePrimaryBusId;
            prime.intelBusId = lib.mkIf effectivePrimeIsIgpuIntel effectivePrimePrimaryBusId;
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
