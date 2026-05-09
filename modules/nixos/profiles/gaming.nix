{
  config,
  lib,
  pkgs,
  inputs, # <--- 1. Catch 'inputs' passed from specialArgs in flake.nix
  ...
}:

################################################################################
# UNIVERSAL GAMING PROFILE MODULE
# ------------------------------------------------------------------------------
# This module provides a flexible and comprehensive gaming configuration,
# consolidating features for both traditional PC gaming and a "leanback" Steam
# Deck-like (console) experience. It includes Steam, game performance tools,
# and integration with Jovian-NixOS for optimized hardware settings.
################################################################################

let
  cfg = config.ft.profiles.gaming;
in
{
  # --- 2. THE FIX: Explicitly import the upstream flake module ---
  # Nix's module system automatically deduplicates, so if two different 
  # profiles import this same Jovian module, it will only load once.
  imports = [
    inputs.jovian-nixos.nixosModules.default
  ];

  options.ft.profiles.gaming = {
    enable = lib.mkEnableOption "Universal Gaming Profile";

    # Toggle for a leanback (Steam Deck UI) experience, booting directly into Steam.
    enableLeanbackUI = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Steam Deck-like UI (boots directly into Steam Big Picture).";
    };

    # The username for the gaming session. Important for Steam and Home Manager.
    user = lib.mkOption {
      type = lib.types.str;
      default = "joe"; # Assuming 'joe' is the default user
      description = "The username for the gaming session.";
    };

    # The desktop environment to use when not in leanback mode (e.g., "plasma", "gnome").
    desktopEnvironment = lib.mkOption {
      type = lib.types.str;
      default = "plasma"; # Default to Plasma as it's common for gaming
      description = "Desktop environment for gaming sessions (e.g., plasma, gnome).";
    };

    # The GPU vendor for hardware optimizations (e.g., "amd", "nvidia", "intel").
    gpuVendor = lib.mkOption {
      type = lib.types.enum [
        "amd"
        "intel"
        "nvidia"
      ];
      default = "amd";
      description = "GPU vendor for hardware optimizations (amd, intel, nvidia).";
    };
  };

  config = lib.mkIf cfg.enable {
    # 1. Gaming Performance Tools
    # Gamemode optimizes system performance for games.
    programs.gamemode.enable = true;

    # Essential gaming utilities and launchers.
    environment.systemPackages = with pkgs; [
      mangohud # In-game overlay for performance metrics
      protonup-qt # GUI for managing Proton versions
      steamtinkerlaunch # Utility for configuring Steam games
      goverlay # GUI for MangoHud and ReplaySorcery
      heroic # Launcher for Epic Games Store and GOG
    ];

    # 2. Steam Client Configuration
    programs.steam = {
      enable = true;
      # Open firewall ports for Steam features.
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
      # Gamescope session for performance and scaling (optional, can be toggled).
      gamescopeSession.enable = false; # Default to false, enable if desired
    };

    # 3. Jovian-NixOS Integration (for Steam Deck-like optimizations)
    jovian.steam = {
      enable = true; # Always enable Jovian for optimizations
      autoStart = cfg.enableLeanbackUI; # Auto-start Steam Big Picture if leanback UI is enabled
      user = cfg.user;
      desktopSession = lib.mkIf cfg.enableLeanbackUI cfg.desktopEnvironment;
    };

    # 4. Decky Loader (for Steam Deck UI plugins)
    jovian.decky-loader.enable = cfg.enableLeanbackUI;

    # 5. Hardware Optimization based on GPU vendor
    # This dynamically applies kernel parameters and Mesa optimizations.
    jovian.hardware.has.amd.gpu = (cfg.gpuVendor == "amd");
    # Add more conditions for Intel/NVIDIA specific Jovian optimizations if they exist.
  };
}