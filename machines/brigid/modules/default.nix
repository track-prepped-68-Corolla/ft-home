# =============================================================================
# Consumer NixOS Module Hub (brigid)
# =============================================================================
#
# Single entry-point for brigid's machine-local NixOS modules. Imported from
# machines/brigid/default.nix and evaluated alongside the framework modules.
# brigid currently has no machine-local modules — its disk layout comes from
# ft.diskBtrfs, not a hand-written disko.nix — so this discovers nothing but
# stays here so the `./modules` import resolves and future machine-local modules
# drop in without edits.
#
# HOW IT WORKS
#   lib.filesystem.listFilesRecursive discovers every .nix file in this tree at
#   evaluation time; the module system evaluates each lazily.
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
