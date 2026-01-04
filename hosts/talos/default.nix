{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./prime.nix
  ];

  networking.hostName = "talos";

  # --- User Configuration ---
  modules.system.user.enable = true;
  mainuser = "joe";
  superUsers = [ "joe" ];

  # --- Modules ---
  modules.desktops.plasma.enable = true;
  modules.services.sddm.enable = true;

  # Enabling NVIDIA since this machine likely has a discrete GPU
  modules.hardware.nvidia.enable = true;
  modules.services.printing.enable = true;

  modules.profiles.couchgaming.enable = true;
  modules.system.virt.enable = true;
  modules.system.podman.enable = true;
  modules.themes.catppuccin.enable = true;
}
