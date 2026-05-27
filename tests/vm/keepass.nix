{ inputs, nixpkgs }:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) baseConfig specialArgs;
in
{
  # ft.keepass: KeePassXC is on PATH and GNOME Keyring is not active.
  vm-keepass-load = pkgs.testers.runNixOSTest {
    name = "ft-keepass-load";
    inherit specialArgs;
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
