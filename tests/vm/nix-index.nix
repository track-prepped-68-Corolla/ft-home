{ inputs, nixpkgs }:
let
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) baseConfig mkTest;
in
{
  # ft."nix-index": the comma binary is available on PATH.
  # (nix-index.enable defaults to true; this test makes the dependency explicit.)
  vm-nix-index-load = mkTest {
    name = "ft-nix-index-load";
    nodes.machine =
      { ... }:
      {
        imports = [ baseConfig ];
        ft."nix-index".enable = true;
      };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("which ,")
    '';
  };
}
