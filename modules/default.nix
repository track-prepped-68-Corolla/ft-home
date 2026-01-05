{
  imports = [

    # Default Apps
    ./apps

    # Desktops
    ./desktops/plasma.nix
    ./desktops/cosmic.nix

    # Hardware
    ./hardware/nvidia.nix
    ./hardware/amd.nix
    ./hardware/asus.nix
    ./hardware/yubikey.nix

    # Profiles
    ./profiles/gaming.nix
    ./profiles/couchgaming.nix

    # Services
    ./services/sddm.nix
    ./services/printing.nix
    ./services/tailscale.nix
    ./services/nfs.nix

    # System
    ./system/virt.nix
    ./system/podman.nix
    ./system/user.nix
    ./system/nh.nix

    # Themes
    ./themes/catppuccin.nix

    # Containers
    ./containers/ai.nix
    ./containers/distrobox.nix
    ./containers/dozzle.nix
    ./containers/jellyfin.nix
  ];
}
