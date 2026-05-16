# =============================================================================
# nixos-config — Consumer Flake
# =============================================================================
#
# This flake is intentionally minimal. All output generation is delegated to
# ft-home.lib.mkFlake, which runs lib/generator.nix against this repo's
# hosts/ and homes/ directories.
#
# Generated outputs:
#   nixosConfigurations.<hostname>        one per hosts/<arch>/<hostname>/
#   darwinConfigurations.<hostname>       one per hosts/<arch>-darwin/<hostname>/
#   homeConfigurations.<user>@<arch>      one per homes/<user>/ x host arch
#
# To add a new host:           create hosts/<arch>/<hostname>/default.nix
# To add a new home:           create homes/<username>/default.nix
# To add a consumer module:    drop a .nix file under modules/nixos/ or modules/home/
# To pull framework updates:   nix flake update ft-home
#
# Do NOT run `nix flake update nixpkgs` — nixpkgs follows ft-home's pin
# and has no standalone input node in this flake.
# =============================================================================
{
  description = "NixOS configuration consuming the ft-home framework";

  inputs = {
    ft-home.url = "github:track-prepped-68-corolla/ft-home/main";

    # Follow ft-home's pins to avoid duplicate fetches and version drift.
    nixpkgs.follows = "ft-home/nixpkgs";
    home-manager.follows = "ft-home/home-manager";
    nixos-facter.follows = "ft-home/nixos-facter";
  };

  outputs = inputs@{ ft-home, ... }: ft-home.lib.mkFlake inputs;
}
