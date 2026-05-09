{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ft.cli;

  flakeDir = config.ft.flakeDir;

  ftWrapper = pkgs.writeShellScriptBin "ft" ''
    exec ${pkgs.just}/bin/just --justfile "${flakeDir}/.justfile" --working-directory "${flakeDir}" "$@"
  '';

in
{
  options.ft.cli = {
    enable = lib.mkEnableOption "Fast Track CLI (ft command)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.just
      ftWrapper
    ];
  };
}
