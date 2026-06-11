{
  config,
  pkgs,
  lib,
  ...
}:

################################################################################
# DEFAULT APPLICATIONS MODULE
################################################################################

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      asusctl
    ];
}
