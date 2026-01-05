{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.containers.jellyfin;
in
{
  options.modules.containers.jellyfin = {
    enable = lib.mkEnableOption "Jellyfin container for Strix Halo (RDNA 3.5)";
  };

  config = lib.mkIf cfg.enable {

    # --- Strix Halo Hardware Requirements ---

    # 1. Graphics & Firmware
    # Strix Halo (RDNA 3.5) requires newer firmware and Mesa drivers.
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      # We rely on standard Mesa VAAPI drivers which handle RDNA 3.5 well.
      # Avoid forcing amdvlk here unless strictly necessary to prevent VAAPI conflicts.
      extraPackages = with pkgs; [
        rocmPackages.clr.icd # OpenCL (optional, for tone mapping)
      ];
    };

    # --- Container Configuration ---

    virtualisation.oci-containers.containers.jellyfin = {
      image = "jellyfin/jellyfin:latest";
      autoStart = true;
      ports = [ "8096:8096" ];

      volumes = [
        # The requested mount
        "/mnt/streaming:/media"

        # Persistence
        "jellyfin-config:/config"
        "jellyfin-cache:/cache"
      ];

      # Environment variables for Jellyfin FFmpeg
      environment = {
        "NVIDIA_VISIBLE_DEVICES" = "all";
      };

      extraOptions = [
        "--device=/dev/dri/renderD128:/dev/dri/renderD128"
        "--device=/dev/dri/card0:/dev/dri/card1"
        # If you want to use OpenCL tone mapping with ROCm:
        "--device=/dev/kfd:/dev/kfd"
      ];
    };

    # Firewall
    networking.firewall = {
      allowedTCPPorts = [ 8096 ];
      allowedUDPPorts = [
        1900
        7359
      ];
    };
  };
}
