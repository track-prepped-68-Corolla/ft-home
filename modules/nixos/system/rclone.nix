{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.ft.rclone;
  # Use the username variable if you have one, or hardcode it to "joe"
  username = "joe";
in
{
  options.ft.rclone = {
    enable = lib.mkEnableOption "Fast Track Google Drive Rclone Service";
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

    # The rclone mount systemd user service belongs in the user's home config
    # (users/<username>/default.nix or a home module), not here. The generator
    # creates standalone homeConfigurations so home-manager.users.* is not
    # a valid NixOS option in this setup.
  };
}
