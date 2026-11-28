{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.ft.jovian;
in
{
  # Upstream gamescope session module — permitted import per style rules.
  imports = [ inputs.nixos-jovian.nixosModules.default ];

  options.ft.jovian = {
    enable = lib.mkEnableOption "Jovian-NixOS gamescope session" // {
      description = "Enables the SteamOS-style gamescope Big Picture session on lyra's media-PC setup.";
    };

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Boots straight into Gaming Mode (gamescope + Steam) via Jovian's SDDM autologin, making gamescope-wayland the default session.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      description = "The local user Gaming Mode autologins and runs Steam as.";
    };

    desktopSession = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "The session Steam's \"Switch to Desktop\" launches; null relaunches Gaming Mode.";
    };
  };

  config = lib.mkIf cfg.enable {
    jovian.steam = {
      enable = lib.mkDefault true;
      autoStart = lib.mkDefault cfg.autoStart;
      user = lib.mkDefault cfg.user;
      desktopSession = lib.mkDefault cfg.desktopSession;
    };
  };
}
