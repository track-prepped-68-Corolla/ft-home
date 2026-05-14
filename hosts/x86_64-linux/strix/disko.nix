{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            # Alphabetical order matches physical order: ESP(p1) root(p2) swap(p3)
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "fmask=0077" "dmask=0077" ];
              };
            };
            root = {
              size = "1880G"; # ~1.9T disk minus ESP and swap
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
            swap = {
              size = "100%"; # takes remaining ~9G
              content = {
                type = "swap";
              };
            };
          };
        };
      };
    };
  };
}
