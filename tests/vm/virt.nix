{ inputs, nixpkgs }:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) baseConfig;
in
{
  # ft.system.virt: libvirtd reaches the active state and virt-manager is on PATH.
  vm-virt-load = pkgs.testers.runNixOSTest {
    name = "ft-virt-load";
    nodes.machine =
      { ... }:
      {
        imports = [ baseConfig ];
        ft.system.virt.enable = true;
        # No USB passthrough available in a nested QEMU environment.
        ft.system.virt.enableSpiceUsbRedirection = false;
      };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("libvirtd.service")
      machine.succeed("which virt-manager")
      machine.succeed("getent group libvirtd")
    '';
  };
}
