{ lib, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    # ft-home framework modules (provides ft.* options, sops, disko, etc.)
    inputs.ft-home.nixosModules.default

    # This repo's additive modules (tailscale, gpu, plasma, etc.)
    ../../modules/nixos
  ];

  networking.hostName = "strix";
  mainuser            = "joe";
  ft.repoPath         = "/home/joe/git/nixos-config";

  u2fMappings = ''
    joe:your_yubikey_public_key_string_here
  '';

  users.users.joe.initialPassword = "nixos";
  users.mutableUsers = true;

  ft.runtimeFacts.enable    = true;
  ft.boot.limine.enable     = true;
  ft.security.sops.enable   = true;
  ft.security.sops.useTPM   = true;
  ft.desktop.cosmic.enable  = true;
  ft.cli.enable             = true;

  programs.zsh.enable = true;
  nixpkgs.hostPlatform = "x86_64-linux";
}
