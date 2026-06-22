# =============================================================================
# joe / creative profile — 3D & creative apps
# =============================================================================
#
# Layered onto joe's base config by the generator's profile combinator only on
# machines that activate it (e.g. strix), producing homeConfigurations like
# joe+creative@x86_64-linux. Lean machines (e.g. brigid) activate the base
# joe@<system> and never pull these in.
#
# Pinned to nixpkgs-stable for ABI stability, matching how they were pinned when
# they lived in users/joe/default.nix.
# =============================================================================
{ pkgs, inputs, ... }:
let
  stable = inputs.nixpkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  home.packages = [
    stable.krita
    stable.openscad
    stable.freecad
    stable.blender
  ];
}
