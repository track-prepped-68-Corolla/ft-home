{ inputs, nixpkgs }:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) consumerBaseConfig;
in
{
  # ft.apps (consumer): key CLI packages from the apps bundle are on PATH.
  vm-apps-load = pkgs.testers.runNixOSTest {
    name = "ft-apps-load";
    nodes.machine =
      { ... }:
      {
        imports = [ consumerBaseConfig ];
        ft.apps.enable = true;
      };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("which rg")
      machine.succeed("which lazygit")
      machine.succeed("which bat")
    '';
  };
}
