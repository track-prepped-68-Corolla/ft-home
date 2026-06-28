# =============================================================================
# joe / gaming profile — gaming user apps
# =============================================================================
#
# Layered onto joe's base config by the generator's profile combinator only on
# machines that activate it (e.g. strix), producing homeConfigurations like
# joe+gaming@x86_64-linux. Pairs with the system-level ft.gaming toggle set in
# the machine config. Lean machines (e.g. brigid) omit both.
# =============================================================================
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    mangohud
    heroic
  ];
}
