{
  lib,
  config,
  ...
}:

################################################################################
# GPU MODULE — auto-detected from facter.json
################################################################################

let
  cfg = config.ft.hardware.gpu;
  facterCfg = config.ft.hardware.facter;

  hasFacter = facterCfg.enable && (builtins.pathExists facterCfg.reportPath);
  report = lib.optionalAttrs hasFacter (builtins.fromJSON (builtins.readFile facterCfg.reportPath));

  pciDevices = report.pci_devices or [ ];
  # PCI class 3 = display controller
  gpuDevices = builtins.filter (d: (d.class_id or (-1)) == 3) pciDevices;

  # Vendor IDs in decimal: AMD=0x1002, NVIDIA=0x10de, Intel=0x8086
  hasAMD = builtins.any (d: (d.vendor_id or 0) == 4098) gpuDevices;
  hasNVIDIA = builtins.any (d: (d.vendor_id or 0) == 4318) gpuDevices;
  hasIntel = builtins.any (d: (d.vendor_id or 0) == 32902) gpuDevices;

  # Convert PCI slot "0000:03:00.0" → "PCI:3:0:0"
  slotToNixBusId =
    slot:
    let
      # Drop domain prefix (0000:) — take the last colon-delimited segment pair
      parts = lib.splitString ":" slot;
      busHex = builtins.elemAt parts (builtins.length parts - 2);
      devFn = builtins.elemAt parts (builtins.length parts - 1);
      devHex = builtins.elemAt (lib.splitString "." devFn) 0;
      fnHex = builtins.elemAt (lib.splitString "." devFn) 1;
      fromHex = s: lib.toInt ("0x" + s);
    in
    "PCI:${toString (fromHex busHex)}:${toString (fromHex devHex)}:${toString (fromHex fnHex)}";

  hasDualGpu = builtins.length gpuDevices >= 2;
  # First entry is the integrated/primary display output, last is the discrete GPU
  primaryGpuSlot = if gpuDevices != [ ] then (lib.head gpuDevices).slot or "" else "";
  discreteGpuSlot = if gpuDevices != [ ] then (lib.last gpuDevices).slot or "" else "";
in
{
  options.ft.hardware.gpu = {
    enable = lib.mkEnableOption "auto GPU configuration from facter" // {
      default = true;
      description = "Configures GPU drivers and hardware acceleration based on PCI device data read from facter.json (via ft.hardware.facter). Detects AMD, NVIDIA, and Intel GPUs automatically and enables PRIME offloading when two GPUs are present. No-op when ft.hardware.facter is disabled or facter.json is absent.";
    };

    enable32Bit = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable 32-bit graphics library support (required for Steam, Wine, and other 32-bit applications).";
    };

    nvidia = {
      openKernelModules = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Use NVIDIA's open-source kernel modules (turing+ architecture required). Set false for Maxwell/Pascal cards.";
      };

      driverPackage = lib.mkOption {
        type = lib.types.enum [
          "stable"
          "beta"
        ];
        default = "beta";
        description = "Which NVIDIA driver series to use. 'beta' tracks the latest release; 'stable' uses the long-lived production branch.";
      };

      enableSettings = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install the nvidia-settings GUI for driver configuration.";
      };

      enablePowerManagement = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable NVIDIA systemd power management (suspend/resume). Experimental — may cause resume issues on some hardware.";
      };

      finegrainedPowerManagement = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable NVIDIA fine-grained power management (RTX 20+ series). Allows the discrete GPU to power down when idle under PRIME offload.";
      };
    };

    prime = {
      enable = lib.mkEnableOption "NVIDIA PRIME offloading" // {
        default = hasDualGpu;
        description = "Enable PRIME offload mode for hybrid GPU setups. Auto-enabled when facter reports two display controllers. The integrated GPU handles the display; the discrete NVIDIA GPU is used on demand via prime-run or the offload wrapper.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.graphics.enable = lib.mkDefault true;
    hardware.graphics.enable32Bit = lib.mkDefault cfg.enable32Bit;

    # AMD — prefer RADV (Mesa) over AMDVLK for Vulkan
    hardware.amdgpu.amdvlk.enable = lib.mkIf hasAMD (lib.mkDefault false);
    hardware.amdgpu.opencl.enable = lib.mkIf hasAMD (lib.mkDefault true);

    # NVIDIA
    services.xserver.videoDrivers = lib.mkIf hasNVIDIA (lib.mkDefault [ "nvidia" ]);

    hardware.nvidia = lib.mkIf hasNVIDIA {
      modesetting.enable = true;
      open = cfg.nvidia.openKernelModules;
      nvidiaSettings = cfg.nvidia.enableSettings;
      package =
        if cfg.nvidia.driverPackage == "beta" then
          config.boot.kernelPackages.nvidiaPackages.beta
        else
          config.boot.kernelPackages.nvidiaPackages.stable;
      powerManagement = {
        enable = cfg.nvidia.enablePowerManagement;
        finegrained = cfg.nvidia.finegrainedPowerManagement;
      };
    };

    # PRIME hybrid offload — only when two GPUs detected
    hardware.nvidia.prime = lib.mkIf (hasNVIDIA && cfg.prime.enable) {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      nvidiaBusId = slotToNixBusId discreteGpuSlot;
      amdgpuBusId = lib.mkIf hasAMD (slotToNixBusId primaryGpuSlot);
      intelBusId = lib.mkIf hasIntel (slotToNixBusId primaryGpuSlot);
    };
  };
}
