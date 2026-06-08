{ inputs, nixpkgs }:
let
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) baseConfig mkTest;
in
{
  # ft.podmanRootless: dedicated podman service user and group are created.
  vm-podman-rootless-load = mkTest {
    name = "ft-podman-rootless-load";
    nodes.machine =
      { ... }:
      {
        imports = [ baseConfig ];
        ft.podmanRootless.enable = true;
      };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("id podman")
      machine.succeed("getent group podman")
    '';
  };
}
