{ inputs, nixpkgs }:
let
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) baseConfig mkTest;
in
{
  # ft.printing: CUPS and Avahi daemon both reach the active state.
  vm-printing-load = mkTest {
    name = "ft-printing-load";
    nodes.machine =
      { ... }:
      {
        imports = [ baseConfig ];
        ft.printing.enable = true;
      };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("cups.service")
      machine.wait_for_unit("avahi-daemon.service")
    '';
  };
}
