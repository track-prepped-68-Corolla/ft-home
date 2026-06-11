{
  config,
  pkgs,
  lib,
  ...
}:

################################################################################
# DEFAULT APPLICATIONS MODULE
################################################################################
{
    environment.systemPackages = with pkgs; [
      asusctl
    ];
}
