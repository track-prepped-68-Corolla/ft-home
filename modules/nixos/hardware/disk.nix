{ config, lib, inputs, ... }:

let cfg = config.ft.disk;
in {
  imports = [ inputs.Disko.nixosModules.disko ];

  options.ft.disk = {
    enable  = lib.mkEnableOption "disko declarative disk partitioning";
    devices = lib.mkOption {
      type        = lib.types.attrsOf lib.types.anything;
      default     = {};
      description = "Passed directly to disko.devices. See github.com/nix-community/disko for schema.";
    };
  };

  config = lib.mkIf cfg.enable {
    disko.devices = cfg.devices;
  };
}
