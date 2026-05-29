# =============================================================================
# joe — Home Manager Configuration
# =============================================================================
#
# Discovered by lib/generator.nix at users/joe/default.nix and becomes
# homeConfigurations.joe@x86_64-linux (and any other active arch).
#
# WHAT GOES HERE
#   modules/home     consumer Home Manager modules (auto-gated by ft.*)
#   home.username    required by home-core.nix to set homeDirectory
#   ft.repoPath      used by terminal.nix, lazyvim.nix, and dotfiles.nix to
#                    build live out-of-store symlink paths into this repo
#   ft.* toggles     enable framework features for this specific user
#   home.packages    user-specific packages not covered by framework modules
#
# Do not import ft-home home modules directly — the generator injects them.
# =============================================================================
{ pkgs, inputs, config, lib, ... }:

{
  imports = [
    inputs.stylix.homeModules.stylix
    ../../modules/home
  ];

  # --- IDENTITY ---
  home.username = "joe";

  # --- FEATURE TOGGLES ---
  ft.home.core.stateVersion = "25.05";
  ft.lazyvim.enable = true;
  ft.theme.enable = true;
  ft.theme.wallpaper = ./wallpapers/default.png;
  ft.repoPath = lib.strings.trim (builtins.readFile ../../var/local/repoPath);

  # --- ENVIRONMENT ---
  home.sessionVariables = {
    EDITOR = "nvim";
    NH_FLAKE = config.ft.repoPath;
  };

  # --- PACKAGES ---
  home.packages = with pkgs; [

    # System / CLI
    fastfetch
    htop
    micro
    yazi

    # Desktop apps
    brave
    kitty
    vesktop
    signal-desktop
    slack
    localsend

    # Development
    github-desktop
    vscodium
    direnv
    nixfmt

    # Creative & office (pinned to stable for ABI stability)
    inputs.nixpkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.krita
    inputs.nixpkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.openscad
    inputs.nixpkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.freecad
    inputs.nixpkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.blender
    inputs.nixpkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.libreoffice

    # Gaming
    mangohud
    heroic
    discord
  ];
}
