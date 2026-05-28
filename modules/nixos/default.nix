{ lib, ... }:
let
  # Get a lazy list of all files in this directory and subdirectories
  allFiles = lib.filesystem.listFilesRecursive ./.;

  # Filter out anything that isn't a .nix file, and ignore THIS file to prevent infinite loops
  validModules = builtins.filter (
    path: lib.hasSuffix ".nix" (builtins.toString path) && path != ./default.nix
  ) allFiles;

  # For each discovered file, generate an inline wrapper module that:
  #   * declares ft.<name>.enable  (so the module is opt-in / lazy)
  #   * imports the real module only when that enable flag is true
  mkWrapper =
    path:
    let
      baseName = baseNameOf path;
      # Use the parent directory name for any default.nix found in a subdirectory
      name =
        if baseName == "default.nix" then
          baseNameOf (dirOf path)
        else
          lib.removeSuffix ".nix" baseName;

      # Partially evaluate the module with stub arguments to extract its meta block.
      # Safe because meta.description must be a static string (no config/pkgs refs).
      raw = import path;
      moduleAttrs =
        if builtins.isFunction raw then
          raw {
            config = { };
            pkgs = { };
            options = { };
            lib = lib;
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
      # The real module is imported (and its config block runs) only when the flag is true.
      imports = lib.optionals config.ft.${name}.enable [ path ];
    };
in
{
  imports = builtins.map mkWrapper validModules;
}
