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
      description = "Enables the SteamOS-style gamescope Big Picture session as a selectable (non-default) SDDM session alongside plasma-bigscreen on lyra's media-PC setup.";
    };
  };

  config = lib.mkIf cfg.enable {
    jovian.steam.enable = lib.mkDefault true;
  };
}
