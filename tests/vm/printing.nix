{ inputs, nixpkgs }:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) baseConfig specialArgs;
in
{
  # ft.services.printing: CUPS and Avahi daemon both reach the active state.
  vm-printing-load = pkgs.testers.runNixOSTest {
    name = "ft-printing-load";
    inherit specialArgs;
    nodes.machine =
      { ... }:
      {
        imports = [ baseConfig ];
        ft.services.printing.enable = true;
      };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("cups.service")
      machine.wait_for_unit("avahi-daemon.service")
    '';
  };
}
