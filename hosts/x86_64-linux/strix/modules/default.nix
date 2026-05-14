{ lib, ... }:
{
  imports = builtins.filter
    (f: lib.hasSuffix ".nix" (toString f) && f != ./default.nix)
    (lib.filesystem.listFilesRecursive ./.);
}
