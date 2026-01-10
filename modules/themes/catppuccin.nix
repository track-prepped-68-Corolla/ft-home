{
  config,
  pkgs,
  lib,
  ...
}:

{
  options.modules.themes.catppuccin = {
    enable = lib.mkEnableOption "Catppuccin global theme";
  };

  config = lib.mkIf config.modules.themes.catppuccin.enable {

    catppuccin = {
      enable = lib.mkDefault true;
      flavor = lib.mkDefault "mocha";
      accent = lib.mkDefault "mauve";
      cache.enable = true;
    };

    catppuccin.grub = {
      enable = lib.mkDefault true;
      flavor = lib.mkDefault "mocha";
    };
    #LMFAO
    #fonts.packages = builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts);

    fonts.packages = with pkgs.nerd-fonts; [
      hack
      jetbrains-mono
    ];

  };
}
