{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# PRINTING SERVICE MODULE
# ------------------------------------------------------------------------------
# This module enables and configures the Common Unix Printing System (CUPS),
# providing a robust and network-aware printing solution for NixOS. It includes
# support for a virtual PDF printer, common printer drivers, and Avahi for
# network printer discovery.
################################################################################

let
  cfg = config.ft.services.printing;
in
{
  options.ft.services.printing = {
    enable = lib.mkEnableOption "CUPS printing service";

    # Enable a virtual PDF printer, allowing you to "print" to a PDF file.
    enableVirtualPdfPrinter = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable CUPS-PDF virtual printer.";
    };

    # List of additional printer drivers to install (e.g., for specific brands).
    extraDrivers = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = "[ pkgs.gutenprint pkgs.hplip ]";
      description = "List of additional printer driver packages.";
    };

    # Enable Avahi for mDNS/Bonjour network printer discovery.
    enableNetworkDiscovery = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Avahi for network printer discovery (mDNS/Bonjour).";
    };
  };

  config = lib.mkIf cfg.enable {
    # 1. Enable the CUPS Daemon
    # This is the core printing service.
    services.printing = {
      enable = true;

      # Enable the Virtual PDF Printer if configured.
      cups-pdf.enable = cfg.enableVirtualPdfPrinter;

      # Add specified extra drivers.
      drivers =
        cfg.extraDrivers
        ++ (with pkgs; [
          # Common drivers often useful even if not explicitly listed
          # gutenprint
          # hplip
          # brlaser
        ]);
    };

    # 2. Enable Avahi for Network Printer Discovery
    # Avahi allows your computer to discover network printers automatically.
    services.avahi = lib.mkIf cfg.enableNetworkDiscovery {
      enable = true;
      nssmdns4 = true; # Enable mDNS for IPv4
      openFirewall = true; # Open firewall for Avahi services
    };

    # Ensure CUPS socket is available for non-root users
    # This typically happens automatically but can be a common troubleshooting step.
    services.udev.extraRules = ''
      TAG=="systemd", ENV{SYSTEMD_ALIAS}+="/dev/lp0"
    '';
  };
}
