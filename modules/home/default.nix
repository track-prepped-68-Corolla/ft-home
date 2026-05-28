{ lib, ... }:
let
  allFiles = lib.filesystem.listFilesRecursive ./. ;

  validModules = builtins.filter (
    path:
      lib.hasSuffix ".nix" (builtins.toString path)
      && path != ./default.nix
  ) allFiles;

  mkWrapper =
    path:
    let
      baseName = baseNameOf path;
      name =
        if baseName == "default.nix" then
          baseNameOf (dirOf path)
        else
          lib.removeSuffix ".nix" baseName;

      raw = import path;
      moduleAttrs =
        if builtins.isFunction raw then
          raw {
            config = { };
            pkgs = { };
            options = { };
            inherit lib;
            inputs = { };
          }
        else
          raw;
      meta = moduleAttrs.meta or { };
    in
    { config, ... }:
    {
      options.ft.${name}.enable = lib.mkEnableOption name // {
        description = meta.description or "Whether to enable ${name}.";
      } // lib.optionalAttrs (meta ? default) { inherit (meta) default; };
      imports = lib.optionals config.ft.${name}.enable [ path ];
    };
in
{
  imports = builtins.map mkWrapper validModules;
}
