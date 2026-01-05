{
  config,
  pkgs,
  lib,
  ...
}:

{
  options.modules.profiles.gaming = {
    enable = lib.mkEnableOption "standard gaming configuration";
  };

  config = lib.mkIf config.modules.profiles.gaming.enable {

    # Jovian-NixOS (Optimizations only, no Deck UI)
    jovian.steam = {
      enable = lib.mkDefault true;
      autoStart = lib.mkDefault false;
      user = config.mainuser; # Ensure 'mainuser' is defined in your options
      desktopSession = "plasma";
    };

    programs.gamemode.enable = true;

    environment.systemPackages = with pkgs; [
      mangohud
      protonup-qt
      steamtinkerlaunch
      goverlay
      heroic
    ];

    programs.steam = {
      enable = lib.mkDefault true;
      remotePlay.openFirewall = lib.mkDefault true;
      dedicatedServer.openFirewall = lib.mkDefault true;
      localNetworkGameTransfers.openFirewall = lib.mkDefault true;
      gamescopeSession.enable = lib.mkDefault false;
    };
  };
}
