{ inputs, nixpkgs }:
let
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) consumerBaseConfig mkTest;
in
{
  # ft.mullet (consumer): packages listed in the source text file are installed.
  # fixtures/mullet.txt contains "hello" and "cowsay".
  vm-mullet-load = mkTest {
    name = "ft-mullet-load";
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
