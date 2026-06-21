# =============================================================================
# lyra — Consumer NixOS Module Hub
# =============================================================================
#
# Single entry-point for machine-local NixOS modules (e.g. disko.nix).
# Imported from machines/lyra/default.nix alongside the framework modules.
# Drop any .nix file here; it is discovered automatically at eval time.
# =============================================================================
{ lib, ... }:
let
  allFiles = lib.filesystem.listFilesRecursive ./.;
  validModules = builtins.filter (
    path: lib.hasSuffix ".nix" (builtins.toString path) && path != ./default.nix
  ) allFiles;
in
{
  imports = validModules;
}
