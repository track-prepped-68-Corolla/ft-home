# =============================================================================
# Consumer NixOS Module Hub
# =============================================================================
#
# Single entry-point for ALL consumer-specific NixOS modules. Imported from
# hosts/<hostname>/default.nix and evaluated alongside the framework modules
# that ft-home injects automatically.
#
# HOW IT WORKS
#   lib.filesystem.listFilesRecursive discovers every .nix file in this tree
#   at evaluation time. The NixOS module system evaluates each lazily — a
#   module's config block only runs when its ft.*.enable option is true.
#
# HOW TO ADD A MODULE
#   Drop a .nix file anywhere under modules/nixos/. No imports list to update.
#   Follow the same ft.*.enable pattern used by framework modules.
# =============================================================================
{ lib, ... }:
let
  allFiles = lib.filesystem.listFilesRecursive ./.;
  # Exclude non-.nix files and this file itself to prevent an import cycle.
  validModules = builtins.filter (
    path: lib.hasSuffix ".nix" (builtins.toString path) && path != ./default.nix
  ) allFiles;
in
{
  imports = validModules;
}
