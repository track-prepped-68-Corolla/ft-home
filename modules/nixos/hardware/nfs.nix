{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ft.nfs;
in
{
  meta.description = "NFS mount management with systemd automount support. Declare mounts under ft.nfs.mounts; each entry needs a remotePath and a mountPoint and is auto-mounted on demand with a 10-minute idle timeout.";

  options.ft.nfs = {
    mounts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            remotePath = lib.mkOption { type = lib.types.str; };
            mountPoint = lib.mkOption { type = lib.types.str; };
          };
        }
      );
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ nfs-utils ];
    services.rpcbind.enable = true;
    boot.supportedFilesystems = [ "nfs" ];

    # mapAttrs' lets us pick the key (mountPoint) manually
    fileSystems = lib.mapAttrs' (
      name: value:
      lib.nameValuePair value.mountPoint {
        device = value.remotePath;
        fsType = "nfs";
        options = [
          "x-systemd.automount"
          "noauto"
          "x-systemd.idle-timeout=600"
          "nfsvers=4.1"
          "soft"
          "intr"
        ];
      }
    ) cfg.mounts;
  };
}
