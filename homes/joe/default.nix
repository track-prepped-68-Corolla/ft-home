{ config, pkgs, inputs, ...}:

{
  imports = [
    # Load the repo's home-manager module library (ft.lazyvim, ft.theme, etc.)
    ../../modules/home
  ];

  # --- User Information ---
  home.username = "joe";
  # home.homeDirectory and home.stateVersion come from modules/home/home-core.nix

  # --- Module Toggles ---
  ft.lazyvim.enable = true;
  ft.theme.enable = true;

  # --- Environment Variables ---
  home.sessionVariables = {
    EDITOR = "nvim";
  };

  # --- Packages ---
  home.packages = with pkgs; [

    # SYSTEM / CLI TOOLS
    fastfetch
    htop
    micro
    yazi

    # DESKTOP APPS
    brave
    kitty
    vesktop
    signal-desktop
    slack
    localsend

    # DEVELOPMENT
    github-desktop
    vscodium
    direnv
    nixfmt

    # CREATIVE & OFFICE
    #krita
    #openscad
    #freecad
    #blender
    inputs.nixpkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.krita
    inputs.nixpkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.openscad
    inputs.nixpkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.freecad
    inputs.nixpkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.blender
    libreoffice

    # GAMING
    mangohud
    heroic
    lutris
    discord
  ];
}
