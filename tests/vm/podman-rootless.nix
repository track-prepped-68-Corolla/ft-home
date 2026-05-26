{ inputs, nixpkgs }:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) baseConfig;
in
{
  # ft.services.podmanRootless: dedicated podman service user and group are created.
  vm-podman-rootless-load = pkgs.testers.runNixOSTest {
    name = "ft-podman-rootless-load";
    nodes.machine =
      { ... }:
      {
        imports = [ baseConfig ];
        ft.services.podmanRootless.enable = true;
      };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("id podman")
      machine.succeed("getent group podman")
    '';
  };
}
