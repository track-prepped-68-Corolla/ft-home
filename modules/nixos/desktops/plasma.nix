{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# KDE PLASMA DESKTOP MODULE
# ------------------------------------------------------------------------------
# This module enables and configures the KDE Plasma 6 Desktop Environment.
# It includes essential Plasma components, common KDE applications, and
# integrates with system services like KDE Connect and KWallet.
################################################################################

let
  cfg = config.ft.desktop.plasma;
in
{
  options.ft.desktop.plasma = {
    enable = lib.mkEnableOption "KDE Plasma Desktop Environment";
  };

  config = lib.mkIf cfg.enable {
    # 1. Enable X Server and Plasma 6 Desktop Manager
    services.xserver.enable = lib.mkDefault true;
    services.desktopManager.plasma6.enable = lib.mkDefault true;

    # 2. Enable KDE Connect for device integration
    programs.kdeconnect.enable = lib.mkDefault true;

    # 3. Install common KDE-specific system packages
    # These are applications that are typically part of a full KDE experience.
    environment.systemPackages = with pkgs; [
      kdePackages.kate # Advanced text editor
      kdePackages.kcalc # Calculator
      kdePackages.spectacle # Screenshot tool
      kdePackages.partitionmanager # Disk partitioning tool
      kdePackages.krdc # Remote desktop client
    ];

    # 4. Exclude unnecessary Plasma packages
    # This helps to keep the installation lean by removing applications
    # that might not be desired.
    environment.plasma6.excludePackages = with pkgs.kdePackages; [
      elisa # Music player (often replaced by other choices)
    ];

    # 5. KWallet Configuration
    # KWallet is KDE's secure credential storage system. Enabling it here
    # ensures that applications can securely store passwords and other secrets.
    security.pam.services.kwallet = {
      name = "kwallet"; # Service name for PAM
      enableKwallet = lib.mkDefault true; # Enable KWallet integration
    };
  };
}
