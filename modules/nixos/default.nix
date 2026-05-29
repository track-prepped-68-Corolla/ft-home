{ lib, ... }:
let
  # Get a lazy list of all files in this directory and subdirectories
  allFiles = lib.filesystem.listFilesRecursive ./. ;

  # Filter out anything that isn't a .nix file, and ignore THIS file to prevent infinite loops
  validModules = builtins.filter (
    path:
      lib.hasSuffix ".nix" (builtins.toString path)
      && path != ./default.nix
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
            inherit lib;
            inputs = { };
          }
        else
          raw;
      meta = moduleAttrs.meta or { };
    in
    {
      options.ft.${name}.enable = lib.mkEnableOption name // {
        description = meta.description or "Whether to enable ${name}.";
      };
      imports = [ path ];
    };
in
{
  # NixOS treats unknown top-level module keys as config assignments.  Individual
  # modules set `meta.description = "..."` so the hub can read it during partial
  # evaluation; declaring the option here absorbs those assignments cleanly.
  # lib.types.lines accepts multiple string definitions (one per module) and
  # concatenates them — no conflict, and the runtime value is never queried.
  options.meta.description = lib.mkOption {
    type = lib.types.lines;
    default = "";
    internal = true;
    description = "Documentation sink — individual modules set this for the hub to read at partial-evaluation time; the runtime value is unused.";
  };

  imports = builtins.map mkWrapper validModules;
}
