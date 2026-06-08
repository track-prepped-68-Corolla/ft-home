{ inputs, nixpkgs }:
let
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) baseConfig mkTest;
in
{
  # ft.virt: libvirtd reaches the active state and virt-manager is on PATH.
  vm-virt-load = mkTest {
    name = "ft-virt-load";
    nodes.machine =
      { ... }:
      {
        imports = [ baseConfig ];
        ft.virt.enable = true;
        # No USB passthrough available in a nested QEMU environment.
        ft.virt.enableSpiceUsbRedirection = false;
      };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("libvirtd.service")
      machine.succeed("which virt-manager")
      machine.succeed("getent group libvirtd")
    '';
  };
}
