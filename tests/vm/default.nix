# =============================================================================
# VM Smoke Tests
# =============================================================================
#
# Minimal NixOS VM tests for the ft-home framework. Run via the
# vm-tests workflow (manual trigger) or locally:
#
#   nix build -L --no-link \
#     --option system-features "nixos-test kvm benchmark big-parallel" \
#     .#vm-core-boot .#vm-tailscale-load
#
# Requirements: x86_64-linux host with /dev/kvm available.
# =============================================================================
{ inputs, nixpkgs }:

let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;

  # Shared base config: ft.system.core + ft.users with the minimum overrides
  # needed for a clean headless QEMU boot.
  baseConfig =
    { lib, ... }:
    {
      imports = [ inputs.ft-home.nixosModules.default ];
      ft.system.core.stateVersion = "25.05";
      ft.users.initialPasswords.admin = "test";
      # Bluetooth has no hardware in QEMU; force-disable to keep systemd healthy.
      hardware.bluetooth.enable = lib.mkForce false;
    };
in
{
  # --------------------------------------------------------------------------
  # vm-core-boot
  # Boots a minimal ft-home system and confirms multi-user.target is reached.
  # Tests that ft.system.core + ft.users are sufficient for a bootable NixOS VM.
  # --------------------------------------------------------------------------
  vm-core-boot = pkgs.testers.runNixOSTest {
    name = "ft-core-boot";
    nodes.machine = baseConfig;
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("id admin")
    '';
  };

  # --------------------------------------------------------------------------
  # vm-tailscale-load
  # Same base config + ft.services.tailscale enabled. Confirms tailscaled.service
  # reaches the active state. Network authentication is not tested.
  # --------------------------------------------------------------------------
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
