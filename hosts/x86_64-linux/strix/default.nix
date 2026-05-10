{ lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../../modules/nixos
  ];

  networking.hostName = "strix";

  mainuser = "joe";
  superUsers = [ "joe" ];

  # Required by sops-nix (secrets/secrets.yaml resolved relative to this path)
  ft.flakeDir = "/home/joe/git/nixos-config";

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

  # Pre-set U2F mapping; enable with ft.hardware.yubikey.enable = true when ready
  ft.hardware.yubikey.u2fMapping = "joe:MMWc0ZbVifMF3Ah0YM3NLnt4xQKLZY75LuZH5LzElyOXheEMiFjC8s0dxFaKMxRvkpBOqz3uIeksC6VcwNF7FQ==,MINo8SZhJxCR+UO9JNJMwKx/Bi+/8TvSOHFCYLLTWhZotMiikV5aAHRKuGV4liqWGVjRdQ==,es256,+presence";

  nixpkgs.hostPlatform = "x86_64-linux";
}
