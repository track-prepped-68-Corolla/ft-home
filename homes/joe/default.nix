{ config, pkgs, inputs, ... }:

{
  imports = [
    # ft-home framework home modules (provides ft.primaryHost, ft.repoPath, ft.hostFacts, etc.)
    inputs.ft-home.homeManagerModules.default

    # This repo's additive home modules (terminal, lazyvim, stylix, etc.)
    ../../modules/home
  ];

  home.username  = "joe";
  ft.primaryHost = "strix";

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  home.packages = with pkgs; [
    fastfetch
    htop
    micro
    yazi

    brave
    kitty
    vesktop
    signal-desktop
    slack
    localsend

    github-desktop
    vscodium
    direnv
    nixfmt

    inputs.nixpkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.krita
    inputs.nixpkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.openscad
    inputs.nixpkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.freecad
    inputs.nixpkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.blender
    libreoffice

    mangohud
    heroic
    lutris
    discord
  ];
}
