{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ft.mullet;

  content = if builtins.pathExists cfg.sourcePath then builtins.readFile cfg.sourcePath else "";
  rawLines = lib.splitString "\n" content;
  pkgNames = builtins.filter (n: n != "") rawLines;

  resolvePkg =
    name:
    let
      pathList = lib.splitString "." name;
    in
    lib.attrsets.attrByPath pathList null pkgs;

  mulletPackages = builtins.filter (p: p != null) (builtins.map resolvePkg pkgNames);

in
{
  options.ft.mullet = {
    enable = lib.mkEnableOption "Imperative package management (The Mullet)" // {
      description = "Reads a plain-text package list from `ft.mullet.sourcePath` (one `pkgs.attr` name per line; dotted paths like `vimPlugins.LazyVim` are supported) and installs all resolved packages as system packages. Silently skips any names that can't be resolved.";
    };
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
