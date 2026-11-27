# =============================================================================
# media — Home Manager Configuration
# =============================================================================
#
# Discovered by lib/generator.nix at users/media/default.nix.
# Intended for the lyra media PC autologin session.
# =============================================================================
{ config, ... }:

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

  # --- STEAM BACKGROUND AUTOSTART (desktop mode) ---
  # lyra boots into Jovian Gaming Mode; Plasma is only reached via Steam's
  # "Switch to Desktop". Like a Steam Deck's desktop mode, start Steam minimized
  # to the tray so Steam Input's Desktop Layout drives the controller as a
  # mouse/keyboard, instead of relaunching Big Picture on top of the desktop.
  xdg.configFile."autostart/steam-bigpicture.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Steam
    Exec=steam -silent
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
      # Brave Origin: its built-in Shields (uBlock Origin-style rules) are the
      # ad blocking for the TV UI; sponsors are skipped by ft.isponsorblocktv
      # on lyra.
      browser = "brave-origin";
      categories = [
        "AudioVideo"
        "Video"
      ];
      # youtube.com/tv only serves the TV ("leanback") UI to TV-like user
      # agents; a desktop Chromium UA gets bounced back to the normal site.
      # YouTube changes which UAs it accepts — swap this string if it stops
      # working.
      extraArgs = [
        "--start-fullscreen"
        "--user-agent=Mozilla/5.0 (PS4; Leanback Shell) Gecko/20100101 Firefox/65.0 LeanbackShell/01.00.01.75 Sony PS4/ (PS4, , no, CH)"
      ];
    };
  };

  # --- STEAM LIBRARY: NON-STEAM SHORTCUTS ---
  # Declarative non-Steam shortcuts (steam-config-nix), so they show up in
  # Gaming Mode's library. Shortcut IDs derive from the name: renaming one makes
  # Steam treat it as a new game (set `seed` to the old name to keep it).
  # Steam Input template: steam-config-nix can't set it, so pick "Web Browser"
  # once in Steam (Controller settings for the shortcut); it persists across
  # rebuilds because the shortcut ID is stable.
  ft.steamConfig.enable = true;
  programs.steam.config.nonSteamApps."YouTube" = {
    # ft-webapp-youtube is installed by ft.webapps above.
    target = "${config.home.profileDirectory}/bin/ft-webapp-youtube";
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
