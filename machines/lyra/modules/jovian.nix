{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.ft.jovian;
in
{
  # Upstream gamescope session module — permitted import per style rules.
  imports = [ inputs.nixos-jovian.nixosModules.default ];

  options.ft.jovian = {
    enable = lib.mkEnableOption "Jovian-NixOS gamescope session" // {
      description = "Enables the SteamOS-style gamescope Big Picture session as the default autologin session on lyra's media-PC setup.";
    };
  };

  config = lib.mkIf cfg.enable {
    jovian.steam = {
      enable = lib.mkDefault true;
      autoStart = lib.mkDefault true;
      user = lib.mkDefault "media";
      # Required once autoStart is true: jovian's own autostart.nix
      # interpolates this into a systemd ExecStart unconditionally and
      # crashes evaluation if left at its default of null. "gamescope-wayland"
      # is upstream's documented fallback — it keeps "Switch to Desktop"
      # relaunching Gaming Mode rather than pointing at a real desktop session.
      desktopSession = lib.mkDefault "gamescope-wayland";
    };
  };
}
