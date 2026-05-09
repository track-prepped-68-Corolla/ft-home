{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# NFS CLIENT MODULE
# ------------------------------------------------------------------------------
# This module provides a flexible way to configure NFS (Network File System)
# client mounts. It ensures necessary NFS utilities are installed, RPCBIND
# is enabled, and dynamically creates `fileSystems` entries based on user
#-defined mounts.
################################################################################

let
  cfg = config.ft.services.nfs;
in
{
  options.ft.services.nfs = {
    enable = lib.mkEnableOption "NFS Client mount management";

    # A set of NFS mounts, where each attribute name can be a descriptive identifier
    # and the value is a submodule defining the remote path and local mount point.
    mounts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            # The remote path of the NFS share (e.g., "nfs-server:/path/to/share").
            remotePath = lib.mkOption {
              type = lib.types.str;
              description = "Remote path of the NFS share (e.g., server:/path).";
            };
            # The local mount point on the NixOS system (e.g., "/mnt/myshare").
            mountPoint = lib.mkOption {
              type = lib.types.str;
              description = "Local mount point for the NFS share.";
            };
          };
        }
      );
      default = { };
      description = "Attribute set of NFS mounts to configure.";
    };
  };

  config = lib.mkIf cfg.enable {
    # 1. Install NFS Utilities
    # The `nfs-utils` package provides client-side tools like `mount.nfs`.
    environment.systemPackages = [ pkgs.nfs-utils ];

    # 2. Enable RPCBIND Service
    # RPCBIND is essential for NFS to function correctly, handling port mapping.
    services.rpcbind.enable = true;

    # 3. Add NFS to Supported Filesystems
    # Ensures the kernel knows how to handle NFS filesystems during boot.
    boot.supportedFilesystems = [ "nfs" ];

    # 4. Dynamically Create File System Entries
    # This section iterates through the `cfg.mounts` attribute set and creates
    # corresponding `fileSystems` entries for each NFS share. These entries
    # are similar to those found in `/etc/fstab`.
    fileSystems = lib.mapAttrs' (
      name: value: # `name` is the attribute key, `value` is the submodule { remotePath, mountPoint }
      lib.nameValuePair "${value.mountPoint}" {
        # The mount point is the key for the fileSystem entry
        device = "${value.remotePath}";
        fsType = "nfs";
        options = [
          "x-systemd.automount" # Automount when accessed, managed by systemd
          "noauto" # Do not mount automatically at boot
          "x-systemd.idle-timeout=600" # Unmount after 600 seconds of inactivity
          "nfsvers=4.1" # Specify NFS protocol version 4.1
          "soft" # Soft mount (requests timeout)
          "intr" # Allow interrupts for hung operations
          "_netdev" # Require network to be up before mounting
        ];
      }
    ) cfg.mounts;
  };
}
