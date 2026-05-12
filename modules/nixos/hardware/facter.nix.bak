{
  lib,
  config,
  inputs,
  pkgs,
  ...
}:

################################################################################
# FACTER MODULE
################################################################################

let
  cfg = config.ft.hardware.facter;
in
{
  imports = [ inputs.nixos-facter.nixosModules.facter ];

  options.ft.hardware.facter = {
    enable = lib.mkEnableOption "nixos-facter hardware detection" // {
      description = "Imports the nixos-facter NixOS module and points it at a facter.json report committed to the host directory. Replaces hardware-configuration.nix for kernel-module and filesystem detection. Generate the report by running 'just facter' on the target machine and saving the output as hosts/<arch>/<hostname>/facter.json.";
    };

    reportPath = lib.mkOption {
      type = lib.types.path;
      default = inputs.self + "/hosts/${pkgs.system}/${config.networking.hostName}/facter.json";
      defaultText = lib.literalExpression ''"<flake>/hosts/''${pkgs.system}/''${config.networking.hostName}/facter.json"'';
      description = "Path to the facter.json committed in the repo. Defaults to the host's own facter.json; only override if the file lives elsewhere.";
    };
  };

  config = lib.mkIf (cfg.enable && builtins.pathExists cfg.reportPath) {
    facter.reportPath = cfg.reportPath;
  };
}
