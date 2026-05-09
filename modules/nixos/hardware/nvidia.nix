{
  config,
  lib,
  pkgs,
  ...
}:

let
  # 'cfg' is a shortcut for accessing the configuration options we define below.
  cfg = config.ft.nvidia;
in
{
  # ============================================================================
  # OPTION DEFINITIONS
  # This section defines the "knobs" you can turn in your configuration.nix.
  # ============================================================================
  options.ft.nvidia = {
    enable = lib.mkEnableOption "Nvidia proprietary drivers (Open Beta)";

    prime = {
      enable = lib.mkEnableOption "Prime Offloading (Hybrid Graphics)";

      primaryGpuVendor = lib.mkOption {
        type = lib.types.enum [
          "amd"
          "intel"
        ];
        default = "amd";
        description = "The vendor of the GPU connected to your display (usually the iGPU).";
      };

      primaryBusId = lib.mkOption {
        type = lib.types.str;
        example = "PCI:35:0:0";
        description = "Bus ID of the GPU connected to the display (Run 'lspci' to find this).";
      };

      nvidiaBusId = lib.mkOption {
        type = lib.types.str;
        example = "PCI:45:0:0";
        description = "Bus ID of the discrete Nvidia GPU.";
      };
    };
  };

  # ============================================================================
  # IMPLEMENTATION
  # This code only runs if 'ft.nvidia.enable' is set to true.
  # ============================================================================
  config = lib.mkIf cfg.enable {

    # --------------------------------------------------------------------------
    # 1. Video Drivers
    # --------------------------------------------------------------------------

    # This loads the proprietary Nvidia kernel modules.
    # Note: We do NOT list 'amdgpu' or 'intel' here; NixOS loads those automatically
    # when it detects the hardware. Adding them here can actually cause conflicts.
    services.xserver.videoDrivers = [ "nvidia" ];

    # --------------------------------------------------------------------------
    # 2. Hardware Configuration
    # --------------------------------------------------------------------------
    hardware.nvidia = {

      # MODESETTING
      # Required for Wayland compositors (like Gamescope/GNOME/KDE) to function.
      # Without this, you will likely get a black screen.
      modesetting.enable = true;

      # OPEN KERNEL MODULES
      # Use the open-source (GPL) kernel modules released by Nvidia.
      # BENEFITS: Better integration with the Linux kernel, required for some cutting-edge features.
      # WARNING: Only works on Turing (RTX 2000 series) cards and newer.
      # If you have a Pascal (GTX 1000) or older card, set this to 'false'.
      open = true;

      # DRIVER PACKAGE (BETA)
      # We explicitly select the 'beta' driver branch.
      # WHY? The 'beta' branch (currently 555+) contains critical fixes for "Explicit Sync".
      # This fixes the flickering/stuttering issues often seen in Wayland/Gamescope.
      package = config.boot.kernelPackages.nvidiaPackages.beta;

      # NVIDIA SETTINGS
      # Installs the 'nvidia-settings' GUI tool for tweaking color/fan profiles.
      nvidiaSettings = true;

      # POWER MANAGEMENT
      powerManagement = {
        # Standard power management (suspend/resume fixes).
        # Usually 'false' unless you have specific suspend issues.
        enable = false;

        # FINEGRAINED POWER CONTROL (D3cold)
        # This is critical for laptops or hybrid setups.
        # It allows the Nvidia card to completely power down (sleep) when not in use.
        # If set to false, the Nvidia card acts as a space heater even when idle.
        finegrained = true;
      };
    };

    # --------------------------------------------------------------------------
    # 3. Graphics Libraries (OpenGL/Vulkan)
    # --------------------------------------------------------------------------
    hardware.graphics = {
      enable = true;
      # Required for playing 32-bit games (like many older Steam titles)
      enable32Bit = true;
    };

    # --------------------------------------------------------------------------
    # 4. PRIME Offloading Logic
    # --------------------------------------------------------------------------
    # This section bridges the two cards only if 'ft.nvidia.prime.enable' is true.
    hardware.nvidia.prime = lib.mkIf cfg.prime.enable {

      # OFFLOAD MODE
      # This configuration sets the iGPU (or primary card) as the default renderer.
      # Heavy tasks are sent to the Nvidia card only when requested via 'nvidia-offload'.
      offload = {
        enable = true;
        enableOffloadCmd = true; # Adds the 'nvidia-offload' command to your path
      };

      # BUS ID CONFIGURATION
      # NixOS needs to know exactly which card is which on the PCI bus.
      nvidiaBusId = cfg.prime.nvidiaBusId;

      # Dynamic Selection:
      # NixOS uses different option keys depending on whether the primary card is AMD or Intel.
      # We use logic here to set the correct one based on your 'primaryGpuVendor' setting.
      amdgpuBusId = lib.mkIf (cfg.prime.primaryGpuVendor == "amd") cfg.prime.primaryBusId;
      intelBusId = lib.mkIf (cfg.prime.primaryGpuVendor == "intel") cfg.prime.primaryBusId;
    };
  };
}
