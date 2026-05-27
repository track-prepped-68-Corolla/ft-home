{ inputs, nixpkgs }:
let
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) consumerBaseConfig mkTest;
in
{
  # ft.hardware.facter (consumer): hardware report is loaded and system boots.
  #
  # The consumer module sets config.facter.reportPath (an option declared by
  # nixos-facter) but does not import that upstream module itself — the
  # generator normally injects it. Tests must import it explicitly.
  vm-facter-load = mkTest {
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
      # hardware.enableRedistributableFirmware = true is set by ft.hardware.facter;
      # verify its effect: linux-firmware is linked into the system profile.
      machine.succeed("test -d /run/current-system/firmware")
    '';
  };
}
