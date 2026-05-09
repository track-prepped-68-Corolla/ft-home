{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:

let
  cfgTheme = config.ft.theme;
  cfgCosmic = config.ft.cosmic;
in
{
  imports = [
    inputs.stylix.homeModules.stylix
  ];

  options = {
    # -------------------------------------------------------------------------
    # Compatibility stubs for cosmic-manager / home-manager version skew.
    # stylix imports cosmic-manager for COSMIC desktop theming; cosmic-manager
    # references Qt and opencode options that were removed in recent
    # home-manager releases. Defining them here as no-ops unblocks evaluation.
    # Remove these once cosmic-manager is updated upstream.
    # -------------------------------------------------------------------------
    programs.opencode.tui = lib.mkOption { type = lib.types.anything; default = null; };
    qt.kvantum            = lib.mkOption { type = lib.types.anything; default = null; };
    qt.platformTheme      = lib.mkOption { type = lib.types.anything; default = null; };

    ft.theme = {
      enable = lib.mkEnableOption "unified system theming via Stylix";

      wallpaper = lib.mkOption {
        type = lib.types.path;
        default = ./pixel-planet.png;
        description = "Path to the primary desktop wallpaper.";
      };

      schemePath = lib.mkOption {
        type = lib.types.either lib.types.path lib.types.str;
        default = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
        description = "Path to the Base16 YAML scheme.";
      };

      schemeName = lib.mkOption {
        type = lib.types.str;
        default = "Catppuccin Mocha";
        description = "Human-readable name of the scheme (used by COSMIC).";
      };

      fonts = {
        sans = {
          name = lib.mkOption { type = lib.types.str; default = "Atkinson Hyperlegible"; };
          package = lib.mkOption { type = lib.types.package; default = pkgs.atkinson-hyperlegible; };
        };
        mono = {
          name = lib.mkOption { type = lib.types.str; default = "AtkynsonMono Nerd Font Mono"; };
          package = lib.mkOption { type = lib.types.package; default = pkgs.nerd-fonts.atkynson-mono; };
        };
        serif = {
          name = lib.mkOption { type = lib.types.str; default = "IBM Plex Serif"; };
          package = lib.mkOption { type = lib.types.package; default = pkgs.ibm-plex; };
        };
        emoji = {
          name = lib.mkOption { type = lib.types.str; default = "Noto Color Emoji"; };
          package = lib.mkOption { type = lib.types.package; default = pkgs.noto-fonts-color-emoji; };
        };
      };
    };

    ft.cosmic.enable = lib.mkEnableOption "COSMIC desktop environment theming logic";
  };

  config = lib.mkMerge [
    (lib.mkIf cfgTheme.enable {
      home.packages = [
        cfgTheme.fonts.sans.package
        cfgTheme.fonts.mono.package
        cfgTheme.fonts.serif.package
        cfgTheme.fonts.emoji.package
      ];

      stylix = {
        enable = true;
        image = cfgTheme.wallpaper;
        base16Scheme = cfgTheme.schemePath;

        fonts = {
          sansSerif  = { package = cfgTheme.fonts.sans.package;  name = cfgTheme.fonts.sans.name; };
          monospace  = { package = cfgTheme.fonts.mono.package;  name = cfgTheme.fonts.mono.name; };
          serif      = { package = cfgTheme.fonts.serif.package; name = cfgTheme.fonts.serif.name; };
          emoji      = { package = cfgTheme.fonts.emoji.package; name = cfgTheme.fonts.emoji.name; };
          sizes = { applications = 12; terminal = 13; desktop = 11; popups = 11; };
        };

        cursor = {
          package = pkgs.catppuccin-cursors.mochaDark;
          name    = "catppuccin-mocha-dark-cursors";
          size    = 24;
        };

        opacity = { terminal = 0.85; applications = 0.95; desktop = 0.90; };

        targets.starship.enable = false;
      };
    })
  ];
}
