{ inputs, nixpkgs }:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) baseConfig;
in
{
  # Minimal boot test: ft.system.core + ft.users.
  # Passes when multi-user.target is reached and the admin user exists.
  vm-core-boot = pkgs.testers.runNixOSTest {
    name = "ft-core-boot";
    nodes.machine = baseConfig;
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("id admin")
    '';
  };
}
