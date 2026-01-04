{
  config,
  pkgs,
  lib,
  ...
}:

{
  options.modules.profiles.couchgaming = {
    enable = lib.mkEnableOption "couch gaming (Steam Deck UI) configuration";
  };

  config = lib.mkIf config.modules.profiles.couchgaming.enable {

    # Jovian-NixOS (Steam Deck UI enabled)
    jovian.steam = {
      enable = lib.mkDefault true;
      autoStart = lib.mkDefault true; # Boots directly into Steam
      user = config.mainuser;
      desktopSession = "plasma";
    };

programs.gamemode.enable = true;

programs.mangohud.enable = true;

environment.systemPackages = with pkgs; [
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
