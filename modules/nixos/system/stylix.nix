{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# STYLIX THEME MODULE (The Paintbrush)
# Requires the host to import inputs.stylix.nixosModules.stylix.
################################################################################

let
  cfg = config.ft.stylix;
in
{
  meta.description = "Unified system theming via Stylix: Catppuccin Mocha palette, Hack Nerd Font mono, Roboto sans, Charter serif, Bibata-Modern-Ice cursor, 90% terminal opacity. Override wallpaper via ft.stylix.wallpaper.";

  options.ft.stylix = {
    wallpaper = lib.mkOption {
      type = lib.types.path;
      description = "Path to your wallpaper image.";
      default = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/dharmx/walls/main/minimal/01.jpg";
        sha256 = "sha256-42fG5tO/vK8n1uE6e12e1f2f/1+1+1+1+1+1+1+1+1+1";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    stylix = {
      enable = true;
      image = cfg.wallpaper;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";

      cursor = {
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Ice";
        size = 24;
      };

      fonts = {
        monospace = {
          package = pkgs.nerd-fonts.hack;
          name = "Hack Nerd Font Mono";
        };
        sansSerif = {
          package = pkgs.roboto;
          name = "Roboto";
        };
        serif = {
          package = pkgs.charter;
          name = "Charter";
        };
        emoji = {
          package = pkgs.noto-fonts-emoji;
          name = "Noto Color Emoji";
        };
        sizes = {
          applications = 12;
          terminal = 12;
          desktop = 10;
          popups = 10;
        };
      };

      opacity = {
        applications = 1.0;
        terminal = 0.90;
        popups = 0.90;
        desktop = 1.0;
      };

      targets = {
        gtk.enable = true;
        console.enable = true;
      };
    };
  };
}
