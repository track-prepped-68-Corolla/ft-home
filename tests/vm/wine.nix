{ inputs, nixpkgs }:
let
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) baseConfig mkTest;
in
{
  # ft.wine: Wine, Winetricks, and Bottles are on PATH.
  vm-wine-load = mkTest {
    name = "ft-wine-load";
    nodes.machine =
      { ... }:
      {
        imports = [ baseConfig ];
        ft.wine.enable = true;
      };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("wine --version")
      machine.succeed("winetricks --version")
      machine.succeed("which bottles")
    '';
  };
}
