{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ft.mullet;

  # Safely read the file, providing an empty string if it doesn't exist yet
  content = if builtins.pathExists cfg.sourcePath then builtins.readFile cfg.sourcePath else "";

  # Clean up the raw text into a list of strings
  rawLines = lib.splitString "\n" content;
  pkgNames = builtins.filter (n: n != "") rawLines;

  # The magic resolver for nested attributes (e.g., "vimPlugins.LazyVim" -> ["vimPlugins" "LazyVim"])
  resolvePkg =
    name:
    let
      pathList = lib.splitString "." name;
    in
    lib.attrsets.attrByPath pathList null pkgs;

  # Map the names to actual packages, filtering out any nulls in case of manual typos
  mulletPackages = builtins.filter (p: p != null) (builtins.map resolvePkg pkgNames);

in
{
  meta.description = "Imperative package management via a plain-text package list (The Mullet). Reads ft.mullet.sourcePath line-by-line and installs every named package, supporting dotted paths like vimPlugins.LazyVim.";

  options.ft.mullet = {
    sourcePath = lib.mkOption {
      type = lib.types.path;
      default = ./mullet.txt;
      description = "Path to the flat text file tracking imperative packages.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = mulletPackages;
  };
}
