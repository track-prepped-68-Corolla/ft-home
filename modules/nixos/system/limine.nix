{ lib, config, ... }:

{
  options.ft.boot.limine = {
    enable = lib.mkEnableOption "the Limine bootloader";
  };

  config = lib.mkIf config.ft.boot.limine.enable {
    boot.loader = {
      limine.enable = true;
      # Required for modern UEFI hardware like the Strix
      efi.canTouchEfiVariables = true;
      # Ensure other bootloaders are disabled to prevent state conflicts
      systemd-boot.enable = lib.mkForce false;
    };
  };
}