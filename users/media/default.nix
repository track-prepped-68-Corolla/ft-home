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

  # --- KIOSK: no screen lock ---
  # media has no password and logs in automatically; the idle screen locker
  # would otherwise demand a password nobody has, effectively logging the TV out.
  ft.plasmaManager.enable = true;
  programs.plasma.kscreenlocker = {
    autoLock = false;
    lockOnResume = false;
  };

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

  # --- WEBAPPS ---
  # Jellyfin is deliberately omitted for now: it runs in a container on mimir
  # (see ft-home/containers/media.yaml) with no committed reverse proxy or
  # stable URL yet. Add it here once that's wired up.
  ft.webapps = {
    enable = true;
    apps.youtube = {
      name = "YouTube";
      url = "https://www.youtube.com/tv";
      categories = [
        "AudioVideo"
        "Video"
      ];
    };
  };

  # --- FLATPAK: RETRODECK ---
  # Requires the host's ft.flatpak.enable (set on machines/lyra).
  ft.flatpak.enable = true;
  services.flatpak.packages = [ "net.retrodeck.retrodeck" ];
}
