{ inputs, nixpkgs }:
let
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) baseConfig mkTest;
in
{
  # ft.keepass: KeePassXC is on PATH and GNOME Keyring is not active.
  vm-keepass-load = mkTest {
    name = "ft-keepass-load";
    nodes.machine =
      { ... }:
      {
        imports = [ baseConfig ];
        ft.keepass.enable = true;
      };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("which keepassxc")
      # The module's key invariant: KeePassXC must be the sole secret service.
      machine.fail("systemctl is-enabled gnome-keyring.service 2>/dev/null")
    '';
  };
}
