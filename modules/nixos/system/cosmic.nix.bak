{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.ft.desktop.cosmic = {
    enable = lib.mkEnableOption "COSMIC Desktop Environment";
  };

  config = lib.mkIf config.ft.desktop.cosmic.enable {

    services.desktopManager.cosmic.enable = lib.mkDefault true;
    services.displayManager.cosmic-greeter.enable = lib.mkDefault true;
    services.system76-scheduler.enable = lib.mkDefault true;
    hardware.graphics.enable = lib.mkDefault true;
  };
}
