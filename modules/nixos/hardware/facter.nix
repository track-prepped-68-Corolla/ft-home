{
  lib,
  config,
  ...
}:

################################################################################
# FACTER MODULE
################################################################################

let
  cfg = config.ft.hardware.facter;
in
{
  options.ft.hardware.facter = {
    enable = lib.mkEnableOption "nixos-facter hardware detection" // {
      description = "Points the nixos-facter NixOS module at a facter.json report committed to the host directory. Replaces hardware-configuration.nix for kernel-module detection. Generate the report by running 'just facter' on the target machine and saving the output as hosts/<arch>/<hostname>/facter.json, then set ft.hardware.facter.reportPath = ./facter.json in the host's default.nix.";
    };

    reportPath = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Absolute path to the facter.json committed in the repo. Use a flake-relative path, e.g. reportPath = ./facter.json; from the host's default.nix.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        # not-detected.nix used to set this implicitly; make it explicit when facter
        # takes over as the hardware detection source.
        hardware.enableRedistributableFirmware = lib.mkDefault true;
      }
      (lib.mkIf (cfg.reportPath != null && builtins.pathExists cfg.reportPath) {
        hardware.facter.reportPath = cfg.reportPath;
      })
    ]
  );
}
