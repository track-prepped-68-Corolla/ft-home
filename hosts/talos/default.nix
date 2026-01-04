{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./prime.nix
  ];

  networking.hostName = "talos";
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;

  # --- User Configuration ---
  modules.system.user.enable = true;
  mainuser = "joe";
  superUsers = [ "joe" ];

  # --- Modules ---
  
  modules.desktops.plasma.enable = true;
  modules.services.sddm.enable = true;
  modules.hardware.amd.enable = true;  
  modules.hardware.nvidia.enable = true;
  modules.services.printing.enable = true;
  modules.profiles.couchgaming.enable = true;
  modules.hardware.yubikey.enable = true;
  modules.system.virt.enable = true;
  modules.system.podman.enable = true;
  modules.system.nh.enable = true;
  modules.containers.distrobox.enable = true;
  modules.themes.catppuccin.enable = true;
}
