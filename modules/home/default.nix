# =============================================================================
# Consumer Home Manager Module Hub
# =============================================================================
#
# Single entry-point for ALL consumer-specific Home Manager modules. Imported
# from homes/<username>/default.nix and evaluated alongside the framework
# modules that ft-home injects automatically.
#
# HOW TO ADD A MODULE
#   Drop a .nix file anywhere under modules/home/. No imports list to update.
#   Follow the same ft.*.enable pattern used by framework modules.
# =============================================================================
{ lib, ... }:
let
  allFiles = lib.filesystem.listFilesRecursive ./.;
  # Exclude non-.nix files and this file itself to prevent an import cycle.
  validModules = builtins.filter
    (path: lib.hasSuffix ".nix" (builtins.toString path) && path != ./default.nix)
    allFiles;
in
{
  imports = validModules;
}
