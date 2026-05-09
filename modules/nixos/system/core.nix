{ pkgs, lib, ... }:

{
  # -------------------------------------------------------------------------
  #  FAST TRACK NIX - BOILERPLATE & DEFAULTS
  # -------------------------------------------------------------------------
  #
  #  This file sets the baseline configuration for EVERY machine you build.
  #
  #  The Goal:
  #  1. Keep host files clean (only unique hardware/features go there).
  #  2. Ensure consistent settings across your fleet (same timezone, same locale).
  #  3. Enable modern Nix features (Flakes) by default.
  #
  #  Note: We use 'lib.mkDefault' for almost everything here.
  #  This allows you to override these settings in a host file if necessary.
  # -------------------------------------------------------------------------

  options = {
    ft.flakeDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/joe/git/ft-home";
      description = "The absolute path to the Fast Track Nix flake directory.";
    };
  };

  config = {

    # --- 1. SYSTEM IDENTITY (The Birthday) ---
    system.stateVersion = "24.05";

    # --- 2. BOOTLOADER (GRUB) ---
    boot.loader.grub = {
      enable = lib.mkDefault true;
      device = "nodev";
      efiSupport = true;
      useOSProber = lib.mkDefault true;
    };
    boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

    # --- 3. HARDWARE & CONNECTIVITY ---
    # Enable NetworkManager (Standard WiFi/Ethernet tool)
    networking.networkmanager.enable = lib.mkDefault true;

    # Enable Bluetooth
    # Most modern users expect Bluetooth to just work for headphones/mice.
    hardware.bluetooth.enable = lib.mkDefault true;
    hardware.bluetooth.powerOnBoot = lib.mkDefault true;

    # --- 4. PRINTING & DISCOVERY ---
    # Enable CUPS (The standard Linux printing system)
    services.printing.enable = lib.mkDefault true;

    # Enable Avahi (Network Discovery)
    # This is REQUIRED for finding wireless printers and scanners.
    services.avahi = {
      enable = lib.mkDefault true;
      nssmdns4 = true;
      openFirewall = lib.mkDefault true;
    };

    # --- 5. NIX SETTINGS ---
    # Enable the modern "Flakes" command line tools.
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    nix.settings.auto-optimise-store = true;
    nixpkgs.config.allowUnfree = true;

    # --- 6. TIME & LOCALE ---
    time.timeZone = lib.mkDefault "America/New_York";
    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

    # --- 7. CORE PACKAGES ---
    # Tools that should be present on ANY system, even a headless server.
    programs.zsh.enable = true; # zsh is the default shell in fsat track

    environment.systemPackages = with pkgs; [
      nano # Text Editor (Emergency backup if NeoVim breaks)
      git # Version Control
      curl # Download tool
      wget # Download tool
      htop # Process Viewer
      tmux # Terminal multiplexer
      home-manager
      lix
      nh
      nvd
      nix-output-monitor
      nixfmt
      findutils
      delta
      git
    ];
  };
}
