{ lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../../modules/nixos
  ];

  networking.hostName = "strix";

  mainuser = "joe";
  superUsers = [ "joe" ];

  users.users.joe.initialPassword = "nixos";
  users.mutableUsers = true;

  # --- FEATURE TOGGLES ---
  ft.boot.limine.enable = true;
  ft.security.sops.enable = true;
  ft.security.sops.useTPM = true;

  ft.desktop.cosmic.enable = true;
  ft.kernel.cachyos.enable = true;
  ft.kernel.cachyos.variant = "bore";

  ft.cli.enable = true;

  programs.zsh.enable = true;

  nixpkgs.hostPlatform = "x86_64-linux";
}
