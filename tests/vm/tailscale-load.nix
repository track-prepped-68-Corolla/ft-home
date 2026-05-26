{ inputs, nixpkgs }:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) baseConfig;
in
{
  # ft.services.tailscale: tailscaled.service reaches the active state.
  # Network authentication is not tested.
  vm-tailscale-load = pkgs.testers.runNixOSTest {
    name = "ft-tailscale-load";
    nodes.machine =
      { lib, ... }:
      {
        imports = [ baseConfig ];
        ft.services.tailscale.enable = true;
        # Tray app is a desktop GUI; suppress it in a headless VM.
        ft.services.tailscale.enableTrayApp = lib.mkForce false;
      };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("tailscaled.service")
    '';
  };
}
