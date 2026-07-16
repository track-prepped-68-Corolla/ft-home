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

  # --- KIOSK: no screen lock, no auto-suspend ---
  # media has no password and logs in automatically; the idle screen locker
  # would otherwise demand a password nobody has, effectively logging the TV out.
  # Auto-suspend is disabled too — a media PC/TV session shouldn't nap mid-idle
  # (e.g. during video playback with no input) the way a laptop would.
  ft.plasmaManager.enable = true;
  programs.plasma.kscreenlocker = {
    autoLock = false;
    lockOnResume = false;
  };
  programs.plasma.powerdevil.AC.autoSuspend.action = "nothing";

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

  # --- GITOPS: keep this kiosk profile self-updating ---
  # Tracks the same repo/branch lyra's NixOS side already deploys via comin
  # (see ft.gitops on machines/lyra), so this account's home-manager profile
  # stays in sync with git the same way the system does, without anyone
  # needing to log in and run `home-manager switch` by hand.
  ft.gitops = {
    enable = true;
    remote.url = "https://github.com/track-prepped-68-Corolla/ft-home.git";
    remote.branch = "main";
    repoPath = "/home/media/.local/share/ft-gitops/ft-home";
    flakeAttr = "media@x86_64-linux";
  };
}
