{ inputs, nixpkgs }:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) consumerBaseConfig mkTest;
in
{
  vm-nixpkgs-failover = mkTest {
    name = "ft-nixpkgs-failover";
    nodes.machine =
      { ... }:
      {
        imports = [ consumerBaseConfig ];
        ft.system.nixpkgsFailover = {
          enable = true;
          # builtins.toFile writes inline content to the Nix store at eval time
          # (no IFD) — valid as a lib.types.path value.
          overridesFile = builtins.toFile "test-overrides.list" "hello\n";
        };
        environment.systemPackages = [ pkgs.hello ];
      };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("hello")
    '';
  };
}
