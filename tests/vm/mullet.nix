{ inputs, nixpkgs }:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) consumerBaseConfig specialArgs;
in
{
  # ft.mullet (consumer): packages listed in the source text file are installed.
  # fixtures/mullet.txt contains "hello" and "cowsay".
  vm-mullet-load = pkgs.testers.runNixOSTest {
    name = "ft-mullet-load";
    inherit specialArgs;
    nodes.machine =
      { ... }:
      {
        imports = [ consumerBaseConfig ];
        ft.mullet = {
          enable = true;
          sourcePath = ./fixtures/mullet.txt;
        };
      };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("which hello")
      machine.succeed("which cowsay")
    '';
  };
}
