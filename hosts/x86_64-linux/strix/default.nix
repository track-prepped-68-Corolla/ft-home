{ lib, ... }:

{
  imports = [
    # 1. The hardware scan for this specific machine
    ./hardware-configuration.nix

    # 2. The Shared Module Library (Magic Collator)
    ../../../modules/nixos
  ];

  networking.hostName = "strix";

  # mainuser controls which user home-manager targets
  mainuser = "joe";
  # superUsers creates the account with isNormalUser + wheel + common groups
  superUsers = [ "joe" ];

  superUsers = [ "joe" ];

  # Add Joe's specific Yubikey mapping here
  #u2fMappings = ''
  #  joe:your_yubikey_public_key_string_here
  #'';

  users.users.joe.initialPassword = "nixos";
  users.mutableUsers = true;

  # --- FEATURE TOGGLES ---
  ft.boot.limine.enable = true;
  ft.security.sops.enable = true;
  ft.security.sops.useTPM = true;

  ft.desktop.cosmic.enable = true;

  ft.cli.enable = true;

  programs.zsh.enable = true;

  nixpkgs.hostPlatform = "x86_64-linux";
}
