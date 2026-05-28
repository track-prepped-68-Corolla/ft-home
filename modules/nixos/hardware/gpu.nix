{
  config,
  lib,
  ...
}:

################################################################################
# UNIVERSAL GPU MODULE
# ------------------------------------------------------------------------------
# Consolidated and flexible configuration for NVIDIA (proprietary/open), AMD,
# and Intel integrated graphics, with PRIME offloading for hybrid systems.
################################################################################

let
  cfg = config.ft.gpu;

  facterPath = config.ft.facter.reportPath;

  facter =
    if cfg.autodetect && facterPath != null && builtins.pathExists facterPath then
      builtins.fromJSON (builtins.readFile facterPath)
    else
      { };

  gpuCards = facter.hardware.graphics_card or [ ];

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

  hexToInt =
    let
      digits = {
        "0" = 0; "1" = 1; "2" = 2; "3" = 3; "4" = 4;
        "5" = 5; "6" = 6; "7" = 7; "8" = 8; "9" = 9;
        "a" = 10; "b" = 11; "c" = 12; "d" = 13; "e" = 14; "f" = 15;
      };
    in
    hex: lib.foldl (acc: c: acc * 16 + digits.${c}) 0 (lib.stringToCharacters (lib.toLower hex));

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

  validSysfsId =
    id: builtins.isString id && builtins.match "[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\\.[0-9a-fA-F]" id != null;
  optimusHasBusIds =
    optIgpuCard ? sysfs_bus_id
    && validSysfsId optIgpuCard.sysfs_bus_id
    && optNvidiaCard ? sysfs_bus_id
    && validSysfsId optNvidiaCard.sysfs_bus_id;
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

  effectivePrimeIsIgpuAmd = if isOptimus then isAmdCard optIgpuCard else isAmd;
  effectivePrimeIsIgpuIntel = if isOptimus then isIntelCard optIgpuCard else isIntel;

in
{
  meta.description = "Universal GPU configuration supporting NVIDIA (proprietary/open), AMD, and Intel, with automatic Optimus/PRIME detection from a facter.json report. Set ft.facter.reportPath to enable autodetect.";

  options.ft.gpu = {
    autodetect = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Detect GPU vendor and Optimus configuration from ft.facter.reportPath.";
    };

    vendor = lib.mkOption {
      type = lib.types.enum [ "nvidia" "amd" "intel" ];
      default = "amd";
      description = "Primary GPU vendor. Ignored when autodetect = true and a known GPU is found in facter.json.";
    };

    enable32Bit = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable 32-bit graphics support.";
    };

    nvidia = {
      openKernelModules = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Use open-source NVIDIA kernel modules (Turing+). Auto-set from facter when autodetect = true.";
      };
      driverPackage = lib.mkOption {
        type = lib.types.enum [ "stable" "beta" ];
        default = "beta";
        description = "NVIDIA driver package to use.";
      };
      enableSettings = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable nvidia-settings GUI.";
      };
      enablePowerManagement = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable NVIDIA power management.";
      };
      finegrainedPowerManagement = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable fine-grained NVIDIA power management (D3cold).";
      };
    };

    prime = {
      enable = lib.mkEnableOption "PRIME GPU offloading (for hybrid graphics)";

      primaryBusId = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "PCI:35:0:0";
        description = "Bus ID of the GPU connected to the display (e.g., iGPU). Auto-derived from facter.json when autodetect = true.";
      };

      secondaryBusId = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "PCI:45:0:0";
        description = "Bus ID of the discrete GPU. Auto-derived from facter.json when autodetect = true.";
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
          (lib.mkIf effectivePrimeEnable {
            prime.offload.enable = true;
            prime.offload.enableOffloadCmd = true;
            prime.nvidiaBusId = effectivePrimeSecondaryBusId;
            prime.amdgpuBusId = lib.mkIf effectivePrimeIsIgpuAmd effectivePrimePrimaryBusId;
            prime.intelBusId = lib.mkIf effectivePrimeIsIgpuIntel effectivePrimePrimaryBusId;
          })
        ];
      })

      (lib.mkIf isAmd {
        hardware.amdgpu.opencl.enable = true;
      })
    ]
  );
}
