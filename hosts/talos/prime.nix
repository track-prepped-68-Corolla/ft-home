# /etc/nixos/nvidia-3090.nix
{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Use hardware.graphics for modern NixOS (24.11+)
  # If on an older version, this might need to be hardware.opengl
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Load the nvidia driver
  services.xserver.videoDrivers = [
    "amdgpu"
    "nvidia"
  ];

  hardware.nvidia = {
    # Use the NVidia open source kernel module
    open = true;

    # Enable the Nvidia settings menu
    nvidiaSettings = true;

    # Modesetting is required for PRIME
    modesetting.enable = true;

    # PRIME Offloading Configuration
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };

      powerManagement = {
        enable = false;
        finegrained = false;
      };

      # AMD: 23:00.0 -> 35:0:0
      # NVIDIA: 2d:00.0 -> 45:0:0
      amdgpuBusId = "PCI:35:0:0";
      nvidiaBusId = "PCI:45:0:0";
    };
  };
}
