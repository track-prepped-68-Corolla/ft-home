{
  config,
  lib,
  inputs,
  ...
}:

let
  cfg = config.ft.disk;
in
{
  imports = [ inputs.Disko.nixosModules.disko ];

  meta.description = "Declarative disk partitioning via disko. Pass a disko device schema to ft.disk.devices and this module hands it straight to disko.devices.";

  options.ft.disk = {
    devices = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Passed directly to disko.devices. See github.com/nix-community/disko for schema.";
    };
  };

  config = lib.mkIf cfg.enable {
    disko.devices = cfg.devices;
  };
}
