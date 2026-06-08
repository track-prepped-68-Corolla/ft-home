{ inputs, ... }:
{
  imports = [ inputs.Disko.nixosModules.disko ];

  # OS system disk — data drives are managed separately by ft.services.bulkPool.
  # Update `device` to the actual OS disk before running nixos-anywhere
  # (use `lsblk` or check facter.json after running nixos-facter on the target).
  disko.devices = {
    disk.system = {
      type = "disk";
      device = "/dev/sda"; # TODO: update to actual OS disk (e.g. /dev/nvme0n1)
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [
                "fmask=0077"
                "dmask=0077"
              ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
