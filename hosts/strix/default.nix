{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "strix";
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;

  # --- User Configuration ---
  modules.system.user.enable = true;
  mainuser = "joe";
  superUsers = [ "joe" ];

  # --- Modules ---
  #modules.desktops.plasma.enable = true;
  #modules.services.sddm.enable = true;
  modules.desktops.cosmic.enable = true;

  # HARDWARE: Switched to AMD for Strix Halo 395
  modules.hardware.amd.enable = true;
  modules.hardware.asus.enable = true;
  modules.hardware.yubikey.enable = true;
  modules.services.printing.enable = true;

  # Gaming Profile
  modules.profiles.gaming.enable = true;

  modules.system.virt.enable = true;
  modules.system.nh.enable = true;
  modules.themes.catppuccin.enable = true;
  modules.services.tailscale.enable = true;

  #network drives
  modules.services.nfs = {
    streaming.enable = true;
  };

  #containers
  modules.system.podman.enable = true;
  modules.containers.distrobox.enable = true;
  modules.containers.dozzle.enable = true;
  modules.containers.distrobox.enableBoxBuddy = true;
  modules.containers.jellyfin.enable = true;
  #modules.containers.mgmt-box.enable = true;
  modules.containers.ai = {
    enable = true;
    modelPath = "/home/joe/models";
    modelName = "qwen2.5-coder-32b-instruct-q8_0.gguf";
    # You can override the port here if needed
    # openWebUiPort = 8888;
  };
}
