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
    # --- NIXOS SYSTEM LEVEL ---
    # These must stay outside the home-manager block
    environment.systemPackages = [
      pkgs.rclone
      pkgs.fuse
    ];
    programs.fuse.userAllowOther = true;

    # --- HOME MANAGER USER LEVEL ---
    home-manager.users.${username} = {
      # In Home Manager, we use 'home.packages' and 'systemd.user.services'
      home.packages = [ pkgs.rclone ];

      systemd.user.services.rclone-gdrive-mount = {
        Unit = {
          Description = "Mount Google Drive (${cfg.remoteName})";
          After = [ "network-online.target" ];
        };

        Service = {
          Type = "simple";
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/${cfg.mountPoint}";
          ExecStart = ''
            ${pkgs.rclone}/bin/rclone mount ${cfg.remoteName}: %h/${cfg.mountPoint} \
              --vfs-cache-mode full \
              --vfs-cache-max-age 24h \
              --vfs-cache-max-size 10G \
              --vfs-fast-fingerprint
          '';
          ExecStop = "/run/current-system/sw/bin/fusermount -u %h/${cfg.mountPoint}";
          Restart = "on-failure";
          RestartSec = "10s";
        };

        Install = {
          WantedBy = [ "default.target" ];
        };
      };
    };
  };
}
