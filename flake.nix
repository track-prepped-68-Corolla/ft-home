# =============================================================================
# nixos-config — Consumer Flake
# =============================================================================
#
# This flake is intentionally minimal. All output generation is delegated to
# ft-home.lib.mkFlake, which runs lib/generator.nix against this repo's
# machines/ and users/ directories.
#
# Generated outputs:
#   nixosConfigurations.<name>        one per machines/<name>/
#   darwinConfigurations.<name>       one per machines/<name>/ (Darwin systems)
#   homeConfigurations.<user>@<arch>  one per users/<user>/ x machine arch
#
# To add a new machine:        create machines/<name>/default.nix
# To add a new user:           create users/<username>/default.nix
# To add a consumer module:    drop a .nix file under modules/nixos/ or modules/home/
# To pull framework updates:   nix flake update ft-home
#
# Do NOT run `nix flake update nixpkgs` — nixpkgs follows ft-home's pin
# and has no standalone input node in this flake.
# =============================================================================
{
  description = "NixOS configuration consuming the ft-home framework";

  inputs = {
    ft-home.url = "github:track-prepped-68-corolla/fast-track-nix/claude/nixos-lazy-imports-RAUQ2";

    # Follow ft-home's pins to avoid duplicate fetches and version drift.
    nixpkgs.follows = "ft-home/nixpkgs";
    home-manager.follows = "ft-home/home-manager";
    nixos-facter.follows = "ft-home/nixos-facter";
  };

  outputs =
    inputs@{ ft-home, nixpkgs, ... }:
    nixpkgs.lib.recursiveUpdate (ft-home.lib.mkFlake inputs) {
      # VM smoke tests — exposed as packages so they stay out of nix flake check.
      # Run manually via the vm-tests workflow or:
      #   nix build -L --option system-features "nixos-test kvm benchmark big-parallel" \
      #     .#vm-core-boot .#vm-tailscale-load
      packages.x86_64-linux = import ./tests/vm { inherit inputs nixpkgs; };
    };
}
