{ inputs, nixpkgs }:
let
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) consumerBaseConfig mkTest;
in
{
  # ft.containers (consumer): Podman stack and companion CLI tools are on PATH.
  # Container images (komodo-db, komodo, periphery) are defined by the module;
  # this test only verifies that the Podman daemon and tooling are installed —
  # container image pulls are not asserted because they require network access.
  vm-containers-load = mkTest {
    name = "ft-containers-load";
    nodes.machine =
      { ... }:
      {
        imports = [ consumerBaseConfig ];
        ft.containers.enable = true;
      };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("which podman")
      machine.succeed("which docker-compose")
      machine.succeed("which distrobox")
      machine.succeed("systemctl is-active podman.socket")
    '';
  };
}
