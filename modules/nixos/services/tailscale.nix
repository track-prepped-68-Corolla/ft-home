{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# TAILSCALE VPN CLIENT MODULE
# ------------------------------------------------------------------------------
# This module enables and configures the Tailscale VPN client, a zero-config
# VPN for building secure networks. It integrates with the `trayscale` GUI
# for desktop environments and sets up necessary firewall rules.
################################################################################

let
  cfg = config.ft.services.tailscale;
in
{
  options.ft.services.tailscale = {
    enable = lib.mkEnableOption "Tailscale VPN client";

    # Enable `trayscale`, a graphical tray application for managing Tailscale.
    enableTrayApp = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Trayscale GUI tray application.";
    };

    # Whether this client should act as a routing feature (e.g., an exit node).
    # Set to "client" for typical usage, "server" if it will be an exit node.
    useRoutingFeatures = lib.mkOption {
      type = lib.types.enum [
        "client"
        "server"
      ];
      default = "client";
      description = "Tailscale routing features (client or server/exit node).";
    };
  };

  config = lib.mkIf cfg.enable {
    # 1. Enable the Tailscale daemon
    # This ensures the core Tailscale service is running on the system.
    services.tailscale = {
      enable = true;
      useRoutingFeatures = cfg.useRoutingFeatures;
    };

    # 2. Add Trayscale to system packages if enabled
    # Trayscale provides a convenient graphical interface for Tailscale status and actions.
    environment.systemPackages = lib.mkIf cfg.enableTrayApp [
      pkgs.trayscale
    ];

    # 3. Firewall Configuration (Recommended)
    # These rules are crucial for Tailscale to function correctly, allowing
    # direct connections and preventing routing issues.
    networking.firewall = {
      # Trust the tailscale0 interface, allowing all traffic on it.
      trustedInterfaces = [ "tailscale0" ];
      # Configure reverse path filtering. "loose" is often safer for VPNs
      # than completely disabling it, which can be done with `false`.
      checkReversePath = "loose";
    };
  };
}
