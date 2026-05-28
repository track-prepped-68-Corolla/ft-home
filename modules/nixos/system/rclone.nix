{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.ft.rclone;
in
{
  meta.description = "Installs rclone and FUSE and enables userspace mounts (allow_other). The actual rclone mount systemd user service should be configured in the user's home module.";

  options.ft.rclone = {
    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "GoogleDrive";
    };
    remoteName = lib.mkOption {
      type = lib.types.str;
      default = "gdrive";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.rclone
      pkgs.fuse
    ];
    programs.fuse.userAllowOther = true;
  };
}
