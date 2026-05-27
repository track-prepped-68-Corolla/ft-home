{ inputs, nixpkgs }:
let
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) baseConfig mkTest;
in
{
  # ft.programs.nixIndex: the comma binary is available on PATH.
  # (nixIndex.enable defaults to true; this test makes the dependency explicit.)
  vm-nix-index-load = mkTest {
    name = "ft-nix-index-load";
    nodes.machine =
      { ... }:
      {
        imports = [ baseConfig ];
        ft.programs.nixIndex.enable = true;
      };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("which ,")
    '';
  };
}
