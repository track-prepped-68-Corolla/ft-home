# =============================================================================
# strix — Host Configuration
# =============================================================================
#
# Discovered by lib/generator.nix at hosts/x86_64-linux/strix/default.nix
# and becomes nixosConfigurations.strix.
#
# WHAT GOES HERE
#   hardware-configuration.nix   machine-specific kernel modules and filesystems
#   modules/nixos                consumer NixOS modules (auto-gated by ft.*)
#   Identity                     hostName, mainuser, superUsers
#   ft.repoPath                  required by sops-nix, the ft CLI, and dotfile paths
#   ft.* feature toggles         enable framework and consumer modules
#
# WHAT DOES NOT GO HERE
#   Do not import ft-home modules directly — the generator injects them.
#   Per-user Home Manager config belongs in homes/<username>/default.nix.
# =============================================================================
{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../../modules/nixos
  ];

  # --- IDENTITY ---
  networking.hostName = "strix";

  # mainuser is read by user.nix, sops.nix, gaming.nix, virt.nix, and others.
  mainuser = "joe";
  superUsers = [ "joe" ];

  # ft.repoPath is used by sops.nix (secrets path), just.nix (ft wrapper),
  # and any module that resolves dotfile or config paths on disk.
  ft.repoPath = "/home/joe/git/nixos-config";

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

  # U2F key pre-registered. Activate hardware auth by also setting
  # ft.hardware.yubikey.enable = true when the key is physically present.
  ft.hardware.yubikey.u2fMapping = "joe:MMWc0ZbVifMF3Ah0YM3NLnt4xQKLZY75LuZH5LzElyOXheEMiFjC8s0dxFaKMxRvkpBOqz3uIeksC6VcwNF7FQ==,MINo8SZhJxCR+UO9JNJMwKx/Bi+/8TvSOHFCYLLTWhZotMiikV5aAHRKuGV4liqWGVjRdQ==,es256,+presence";

  nixpkgs.hostPlatform = "x86_64-linux";
}
