{ config, lib, ... }:

let
  targetPath = "${config.ft.repoPath}/homes/${config.home.username}/dotfiles";
  prefixLen = builtins.stringLength targetPath + 1;
in
{
  options.ft = {
    repoPath = lib.mkOption { type = lib.types.str; };
    dotfiles.enable = lib.mkEnableOption "dotfiles symlinking" // {
      description = "Recursively symlinks every file under `ft.repoPath/homes/<username>/dotfiles/` into Home Manager's home.file set using out-of-store symlinks, so dotfiles stay live-editable. Staging version — prefer `ft.dotfiles.enable` from ft-home/modules/home/dotfiles.nix which uses the configurable `ft.dotfiles.path` instead of a hardcoded convention.";
    };
  };

  config = lib.mkIf config.ft.dotfiles.enable {
    home.file = builtins.listToAttrs (
      map (
        file:
        let
          pathStr = toString file;
        in
        {
          name = builtins.substring prefixLen (builtins.stringLength pathStr) pathStr;
          value.source = config.lib.file.mkOutOfStoreSymlink pathStr;
        }
      ) (lib.filesystem.listFilesRecursive (/. + targetPath))
    );
  };
}
