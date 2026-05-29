{ inputs, nixpkgs }:
let
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) baseConfig mkTest;
in
{
  # ft.just: the `ft` wrapper script and `just` are both on PATH.
  # ft.repoPath is embedded in the script at build time; the path only needs
  # to exist at runtime for `ft` commands to work, not at evaluation time.
  vm-cli-load = mkTest {
    name = "ft-cli-load";
    nodes.machine =
      { ... }:
      {
        imports = [ baseConfig ];
        ft.repoPath = "/tmp/fake-repo";
        ft.just.enable = true;
      };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("which ft")
      machine.succeed("which just")
    '';
  };
}
