{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# COSMIC DESKTOP ENVIRONMENT MODULE
# ------------------------------------------------------------------------------
# This module enables and configures the COSMIC Desktop Environment, including
# its display manager (cosmic-greeter) and integration with system76-scheduler
# for optimized performance. It also ensures graphics hardware is enabled.
################################################################################

let
  cfg = config.ft.desktop.cosmic;
in
{
  options.ft.desktop.cosmic = {
    enable = lib.mkEnableOption "COSMIC Desktop Environment";
  };

  config = lib.mkIf cfg.enable {
    # 1. Enable the COSMIC Desktop Manager
    services.desktopManager.cosmic.enable = lib.mkDefault true;

    # 2. Enable the COSMIC Greeter (display manager)
    services.displayManager.cosmic-greeter.enable = lib.mkDefault true;

    # 3. Enable System76 Scheduler for performance optimization
    services.system76-scheduler.enable = lib.mkDefault true;

    # 4. Ensure graphics hardware is enabled for the desktop environment
    hardware.graphics.enable = lib.mkDefault true;
  };
}
