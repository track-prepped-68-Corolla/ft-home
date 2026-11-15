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
{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:

{
  imports = [
    ../../modules/home
  ];

  # --- IDENTITY ---
  home.username = "joe";

  # --- FEATURE TOGGLES ---
  ft.core.stateVersion = "25.05";
  ft.lazyvim.enable = true;
  ft.theme.enable = true;
  ft.theme.wallpaper = ./wallpapers/default.png;
  ft.plasmaManager.enable = true;
  ft.karousel.enable = false;
  # ft.dotfiles.enable = true;
  ft.noctalia.enable = true;
  ft.vicinae.enable = true;
  ft.mullet.enable = true;
  ft.cad3d.enable = true;
  ft.atuin.enable = true;
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
    signal-desktop
    slack
    localsend
    appimage-run # runs Frame Control's AppImage (see desktop entry below)

    # Development
    github-desktop
    vscodium
    direnv
    nixfmt

    # Office (pinned to stable for ABI stability)
    inputs.nixpkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.libreoffice

    # Chat
    discord
  ];

  # --- FRAME CONTROL ---
  # Distributed only as an AppImage (not in nixpkgs, no flake), which updates
  # itself in place, so the file lives in ~/Applications rather than the
  # store. appimage-run supplies the FUSE/runtime libraries NixOS lacks;
  # Electron's sandbox helper can't start inside it, hence --no-sandbox.
  xdg.desktopEntries.frame-control = {
    name = "Frame Control";
    comment = "Companion app for the Frame headset";
    exec = "env ELECTRON_DISABLE_SANDBOX=1 appimage-run ${config.home.homeDirectory}/Applications/Frame-Control-linux-x86_64.AppImage --no-sandbox %U";
    icon = "${pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/saphid/frame-control/27d628708acc3cd9d041f5e83d189071ec00baae/app/build/icon.png";
      hash = "sha256-4Z4qp3mT3DMgRXi4hkFMNfBTBJoOLFkr0kJdS9g4kUs=";
    }}";
    categories = [ "Utility" ];
    terminal = false;
  };
}
