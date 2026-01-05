{ config, lib, pkgs, ... }:

let
  cfg = config.modules.services.nfs;
  
  # 1. Define your Inventory here. 
  # This is the only place you ever need to touch IPs or Paths.
  knownMounts = {
    streaming = {
      server = "100.73.5.28";
      path = "/streaming";
    };
    # Add more here as needed...
  };

  # Helper to create the fileSystem config for a given share name
  mkMount = name: {
    device = "${knownMounts.${name}.server}:${knownMounts.${name}.path}";
    fsType = "nfs";
    options = [ "x-systemd.automount" "noauto" "_netdev" "noresvport" ];
  };

in
{
  options.modules.services.nfs = {
    # Create an 'enable' option for every key in your knownMounts
    streaming.enable = lib.mkEnableOption "Streaming Share";
  };

  config = lib.mkMerge [
    # 1. Base NFS support (if ANY share is enabled)
    (lib.mkIf (lib.any (x: x) [ cfg.streaming.enable cfg.downloads.enable cfg.work.enable ]) {
      boot.supportedFilesystems = [ "nfs" ];
      environment.systemPackages = [ pkgs.nfs-utils ];
    })

    # 2. Mount Logic
    (lib.mkIf cfg.streaming.enable {
      fileSystems."/mnt/streaming" = mkMount "streaming";
    })
  ];
}