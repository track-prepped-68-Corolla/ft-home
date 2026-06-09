# =============================================================================
# media — Home Manager Configuration
# =============================================================================
#
# Discovered by lib/generator.nix at users/media/default.nix.
# Intended for the lyra media PC autologin session.
# =============================================================================
{ ... }:

{
  imports = [
    ../../modules/home
  ];

  # --- IDENTITY ---
  home.username = "media";
  ft.core.stateVersion = "25.05";

  # --- STEAM BIG PICTURE AUTOSTART ---
  # Launches Steam in Big Picture / gamepad UI mode when the KDE session starts.
  xdg.configFile."autostart/steam-bigpicture.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Steam Big Picture
    Exec=steam -gamepadui
    Terminal=false
    X-GNOME-Autostart-enabled=true
  '';
}
