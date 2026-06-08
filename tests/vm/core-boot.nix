{ inputs, nixpkgs }:
let
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) baseConfig mkTest;
in
{
  # Minimal boot test: ft.core + ft.users.
  # Passes when multi-user.target is reached and the admin user exists.
  vm-core-boot = mkTest {
    name = "ft-core-boot";
    nodes.machine = baseConfig;
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("id admin")
    '';
  };
}
