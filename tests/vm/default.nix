# =============================================================================
# VM Smoke Tests — Entry Point
# =============================================================================
#
# Merges all per-module test files into a single attrset of
# packages.x86_64-linux.vm-* derivations.
#
# Run a single test locally:
#   nix build -L --no-link \
#     --option system-features "nixos-test kvm benchmark big-parallel" \
#     .#vm-core-boot
#
# Requirements: x86_64-linux host with /dev/kvm available.
# =============================================================================
{ inputs, nixpkgs }:

let
  inherit (nixpkgs) lib;
  args = { inherit inputs nixpkgs; };
in
lib.foldl lib.recursiveUpdate { } (
  map (f: import f args) [
    ./core-boot.nix
    ./tailscale-load.nix
    ./podman-rootless.nix
    ./printing.nix
    ./keepass.nix
    ./nix-index.nix
    ./virt.nix
    ./nfs-framework.nix
    ./cli.nix
    ./apps.nix
    ./mullet.nix
    ./facter.nix
    ./nfs-consumer.nix
    ./rclone.nix
    ./local-ai.nix
    ./wine.nix
    ./ssh.nix
  ]
)
