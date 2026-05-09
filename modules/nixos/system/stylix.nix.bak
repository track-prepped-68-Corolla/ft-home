{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# STYLIX THEME MODULE (The Paintbrush)
# ------------------------------------------------------------------------------
# This module acts as the "Central Style Engine" for your operating system.
#
# WITHOUT STYLIX:
# You have to manually edit kitty.conf, gtk.css, waybar.css, etc., trying to
# make the colors match. It is tedious and fragile.
#
# WITH STYLIX:
# You choose ONE wallpaper and ONE color scheme here. Stylix then calculates
# the perfect palette and forces every application (Terminal, VS Code, Browser,
# Desktop) to use it.
#
# CURRENT PRESET:
# - Colors: Catppuccin Mocha (Dark Pastel)
# - Mono Font: Hack Nerd Font (Coding/Terminal)
# - UI Font: Roboto (Menus/Buttons)
# - Reading Font: Charter (Documents)
# - Emojis: Noto Color Emoji
################################################################################

let
  # Create a shortcut 'cfg' to access our custom options
  cfg = config.ft.theme;
in
{
  # ----------------------------------------------------------------------------
  # 1. DEFINE OPTIONS (The Control Panel)
  # ----------------------------------------------------------------------------
  # This section defines the "knobs" you can turn in your main configuration.
  options.ft.theme = {
    enable = lib.mkEnableOption "the Fast Track Stylix theme engine";

    # The Wallpaper Option
    # We allow the user to provide a path to an image file.
    # If they don't provide one, we download a placeholder from the internet.
    wallpaper = lib.mkOption {
      type = lib.types.path;
      description = "Path to your wallpaper image.";

      # Default: A nice minimal mountain landscape
      default = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/dharmx/walls/main/minimal/01.jpg";
        sha256 = "sha256-42fG5tO/vK8n1uE6e12e1f2f/1+1+1+1+1+1+1+1+1+1";
      };
    };
  };

  # ----------------------------------------------------------------------------
  # 2. CONFIGURATION (The Engine)
  # ----------------------------------------------------------------------------
  # This block only executes if 'ft.theme.enable = true;' is set.
  config = lib.mkIf cfg.enable {

    stylix = {
      # Activate the engine
      enable = true;

      # --- A. THE IMAGE ---
      # Stylix will use this image to generate a color palette (if we didn't
      # specify a scheme) and set it as the background for:
      # 1. The Desktop
      # 2. The Login Screen (Display Manager)
      # 3. The Bootloader (GRUB/Systemd-boot)
      image = cfg.wallpaper;

      # --- B. THE COLORS ---
      # We explicitly choose "Catppuccin Mocha".
      # This overrides the auto-generated colors from the wallpaper, ensuring
      # we always get that specific, consistent dark-pastel look.
      base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";

      # --- C. THE CURSOR ---
      # "Bibata-Modern-Ice" is a sleek, white-and-black cursor.
      # It is widely considered one of the best Linux cursor themes.
      cursor = {
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Ice";
        size = 24;
      };

      # --- D. THE FONTS ---
      # Fonts are critical for a "professional" feel.
      # We define the hierarchy here, and Stylix injects it into every app.
      fonts = {
        # 1. Monospace (The most important one)
        # Used in: Terminal, VS Code, Log files.
        # We use "Nerd Font" to ensure icons (git branches, docker logos) work.
        monospace = {
          package = pkgs.nerd-fonts.hack;
          name = "Hack Nerd Font Mono";
        };

        # 2. Sans Serif (The UI font)
        # Used in: Firefox interface, File Explorer, System Menus.
        # "Roboto" is neutral, readable, and modern.
        sansSerif = {
          package = pkgs.roboto;
          name = "Roboto";
        };

        # 3. Serif (The Reading font)
        # Used in: E-books, PDFs, some web pages.
        # "Charter" is a high-quality, professional serif font.
        serif = {
          package = pkgs.charter;
          name = "Charter";
        };

        # 4. Emojis
        # Ensures colorful emojis appear everywhere instead of empty boxes.
        emoji = {
          package = pkgs.noto-fonts-emoji;
          name = "Noto Color Emoji";
        };

        # 5. Font Sizes
        sizes = {
          applications = 12; # Standard UI text size
          terminal = 12; # Terminal text size
          desktop = 10; # Desktop icons / widgets
          popups = 10; # Tooltips and notifications
        };
      };

      # --- E. OPACITY (The "Cyberpunk" Feel) ---
      # We set the terminal to 0.90 (90%) opacity.
      # This lets the wallpaper bleed through slightly, creating depth.
      opacity = {
        applications = 1.0; # Keep web browsers/docs solid (readability)
        terminal = 0.90; # Transparent terminal
        popups = 0.90; # Transparent menus
        desktop = 1.0; # Solid desktop background
      };

      # --- F. TARGETS ---
      # Which applications should Stylix touch?
      targets = {
        # Theme GTK apps (Nautilus, etc.) to match our colors
        gtk.enable = true;

        # Theme the Linux kernel console (TTY) so even the boot logs match!
        console.enable = true;
      };
    };
  };
}
