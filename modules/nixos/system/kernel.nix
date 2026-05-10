{ lib, config, pkgs, inputs, ... }:
{
  options.ft.kernel.cachyos = {
    enable = lib.mkEnableOption "CachyOS optimized kernel";
    variant = lib.mkOption {
      type = lib.types.enum [
        "latest"     "latest-lto"
        "bore"       "bore-lto"
        "eevdf"      "eevdf-lto"
        "bmq"        "bmq-lto"
        "lts"        "lts-lto"
        "rt-bore"    "rt-bore-lto"
        "hardened"   "hardened-lto"
        "server"     "server-lto"
        "rc"         "rc-lto"
        "deckify"    "deckify-lto"
      ];
      default = "latest";
      description = "CachyOS kernel variant. Maps to linux-cachyos-<variant> from nix-cachyos.";
    };
  };

  config = lib.mkIf config.ft.kernel.cachyos.enable {
    boot.kernelPackages = pkgs.linuxPackagesFor
      inputs.nix-cachyos.packages.${pkgs.stdenv.hostPlatform.system}."linux-cachyos-${config.ft.kernel.cachyos.variant}";
  };
}
