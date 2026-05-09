{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# VIRTUALIZATION MODULE
# ------------------------------------------------------------------------------
# This module provides a comprehensive setup for various virtualization
# technologies, including Libvirt (KVM/QEMU), Incus (LXD fork), and VMware
# workstation. It aims to offer a unified configuration for managing virtual
# machines and containers on NixOS.
################################################################################

let
  cfg = config.ft.system.virt;
in
{
  options.ft.system.virt = {
    enable = lib.mkEnableOption "Comprehensive virtualization setup (Libvirt, Incus, VMware)";

    # Enable VMware Workstation host support.
    enableVmwareHost = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable VMware Workstation host support.";
    };

    # Enable Incus (LXD fork) container hypervisor.
    enableIncus = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Incus (LXD fork) container hypervisor.";
    };

    # Enable SPICE USB redirection for virtual machines.
    enableSpiceUsbRedirection = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable SPICE USB redirection for VMs.";
    };
  };

  config = lib.mkIf cfg.enable {
    # 1. Libvirt (KVM/QEMU) Configuration
    # Libvirt is a virtualization management layer for KVM/QEMU.
    virtualisation.libvirtd.enable = true;
    programs.virt-manager.enable = true; # GUI for managing Libvirt VMs

    # Add the main user to the 'libvirtd' group for permission to manage VMs.
    users.groups.libvirtd.members = [ config.mainuser ];

    # Enable SPICE USB redirection if configured. Useful for passing USB devices to VMs.
    virtualisation.spiceUSBRedirection.enable = cfg.enableSpiceUsbRedirection;

    # 2. VMware Workstation Host Support
    # This enables the necessary services for running VMware Workstation VMs.
    virtualisation.vmware.host.enable = lib.mkIf cfg.enableVmwareHost true;

    # 3. Incus Container Hypervisor
    # Incus is a powerful system container manager.
    virtualisation.incus = lib.mkIf cfg.enableIncus {
      enable = true;
      package = pkgs.incus;
    };

    # 4. NFTables for Firewall Management
    # Often required for advanced virtualization networking setups.
    networking.nftables.enable = lib.mkDefault true; # Default to true, can be overridden
  };
}
