{ inputs, nixpkgs }:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) consumerBaseConfig;
in
{
  # ft.hardware.facter (consumer): hardware report is loaded and system boots.
  #
  # The consumer module sets config.facter.reportPath (an option declared by
  # nixos-facter) but does not import that upstream module itself — the
  # generator normally injects it. Tests must import it explicitly.
  vm-facter-load = pkgs.testers.runNixOSTest {
    name = "ft-facter-load";
    nodes.machine =
      { ... }:
      {
        imports = [
          consumerBaseConfig
          inputs.nixos-facter.nixosModules.facter
        ];
        ft.hardware.facter = {
          enable = true;
          reportPath = ./fixtures/facter.json;
        };
      };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("test -d /run/current-system")
    '';
  };
}
