# =============================================================================
# ft-home — Consumer Flake
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
# VM smoke tests now live in the ft-testing repo:
#   https://github.com/track-prepped-68-Corolla/ft-testing
#
# Do NOT run `nix flake update nixpkgs` — nixpkgs follows ft-home's pin
# and has no standalone input node in this flake.
# =============================================================================
{
  description = "NixOS configuration consuming the ft-home framework";

  inputs = {
    ft-home.url = "github:track-prepped-68-corolla/fast-track-nix/testing";

    # Follow ft-home's pins to avoid duplicate fetches and version drift.
    nixpkgs.follows = "ft-home/nixpkgs";
    nixpkgs-stable.follows = "ft-home/nixpkgs-stable";
    home-manager.follows = "ft-home/home-manager";
    nixos-facter.follows = "ft-home/nixos-facter";

    # AMD NPU/GPU AI stack for strix halo. Intentionally does not follow
    # nixpkgs — pinning it would bust the upstream binary cache for
    # llama.cpp, whisper.cpp, and stable-diffusion.cpp.
    nix-amd-ai.url = "github:noamsto/nix-amd-ai";

    # AI coding agent packages (Claude Code, among ~150 others). Intentionally
    # does not follow nixpkgs — llm-agents.nix is only built/tested against
    # its own pinned nixpkgs-unstable, and following would bust the Numtide
    # binary cache.
    llm-agents.url = "github:numtide/llm-agents.nix";

    # SteamOS-style gamescope session (Big Picture) for lyra's media-PC setup.
    nixos-jovian = {
      url = "github:Jovian-Experiments/Jovian-NixOS";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ ft-home, ... }: ft-home.lib.mkFlake inputs;
}
