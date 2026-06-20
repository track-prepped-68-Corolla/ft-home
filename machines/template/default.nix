# =============================================================================
# template — reference machine (copy me)
# =============================================================================
#
# A clean, minimal machine that evaluates green through `ft _preflight`:
# no sops/facter/ssh wired (nothing to BLOCK or WARN on yet), admin provided
# automatically by ft.admin. Copy this directory to machines/<name>/, set the
# hostname, and work through the REAL-MACHINE TODOs below.
#
# Discovered by the generator at machines/template/default.nix and becomes
# nixosConfigurations.template.
# =============================================================================
{ lib, ... }:

{
  imports = [
    ./modules
    ../../modules/nixos
  ];

  networking.hostName = "template";
  ft.repoPath = lib.strings.trim (builtins.readFile ../../var/local/repoPath);

  # --- ADMIN ---
  # Always present via ft.admin (enabled by default): user "admin", wheel,
  # initialPassword "changeme". For a real host, wire a key and change/clear
  # the password:
  #   ft.admin.authorizedKeys = [ "ssh-ed25519 AAAA... you@host" ];
  #   ft.admin.initialPassword = null;   # rely on keys only
  ft.users.mainUser = "admin";
  users.mutableUsers = true;

  # --- BASELINE FEATURES ---
  ft.limine.enable = true;
  ft.cli.enable = true;

  ft.diskBtrfs = {
    enable = true;
    # select-disk.sh rewrites device (and confirmDevice) at deploy time.
    device = "/dev/nvme0n1";
  };

  # --- REAL-MACHINE TODOs (enable when provisioning the actual hardware) ---
  # 1. Hardware:  `ft generate-facts <name> <ip>`, then add:
  #      ft.facter = { enable = true; reportPath = ./var/facter.json; };
  # 2. Secrets:   `ft secrets-init <name>`, replace the &<name> recipient in
  #               var/secrets/.sops.yaml and `sops updatekeys`, then:
  #      ft.sops.enable = true;
  # 3. Remote access:
  #      ft.ssh = { enable = true; user = "admin"; authorizedKeys = [ ... ]; };

  ft.core.stateVersion = "25.05";
  nixpkgs.hostPlatform = "x86_64-linux";
}
