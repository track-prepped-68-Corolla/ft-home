{
  config,
  pkgs,
  lib,
  ...
}:

{
  options.modules.services.sddm = {
    enable = lib.mkEnableOption "SDDM Display Manager";
  };

  config = lib.mkIf config.modules.services.sddm.enable {

    services.xserver.enable = lib.mkDefault true;

    #  services.displayManager.sddm = {
    #   enable = lib.mkDefault true;
    #   wayland.enable = lib.mkDefault true;
    #  };

    services.xserver.xkb = {
      layout = lib.mkDefault "us";
      variant = lib.mkDefault "";
    };
  };
}
