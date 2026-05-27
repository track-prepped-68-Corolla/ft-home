{ inputs, nixpkgs }:
let
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) baseConfig mkTest;
in
{
  # ft.services.tailscale: tailscaled.service reaches the active state.
  # Network authentication is not tested.
  vm-tailscale-load = mkTest {
    name = "ft-tailscale-load";
    nodes.machine =
      { ... }:
      {
        imports = [ baseConfig ];
        ft.services.tailscale.enable = true;
        # Tray app is a desktop GUI; suppress it in a headless VM.
        ft.services.tailscale.enableTrayApp = false;
      };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("tailscaled.service")
    '';
  };
}
