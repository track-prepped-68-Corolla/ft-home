{ inputs, nixpkgs }:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) baseConfig specialArgs;
in
{
  # ft.programs.nixIndex: the comma binary is available on PATH.
  # (nixIndex.enable defaults to true; this test makes the dependency explicit.)
  vm-nix-index-load = pkgs.testers.runNixOSTest {
    name = "ft-nix-index-load";
    inherit specialArgs;
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
