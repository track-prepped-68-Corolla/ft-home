# =============================================================================
# VM Test Shared Library
# =============================================================================
#
# Provides two base NixOS module configs and a test runner for all VM smoke
# tests:
#
#   baseConfig         — framework modules only
#   consumerBaseConfig — framework + ft-home consumer modules (modules/nixos/)
#   mkTest             — wraps pkgs.testers.runNixOSTest with node.specialArgs
#                        so every node receives `inputs` via specialArgs rather
#                        than _module.args, making it safe to use in `imports`
#
# mergedInputs replicates what lib.mkFlake does so framework modules that
# reference inputs.* at import time (sops-nix, nix-index-database, etc.)
# can evaluate correctly inside the test's NixOS module system.
#
# disko-btrfs and gaming.nix are excluded via disabledModules — see inline
# comments in baseConfig for the reason each is disabled.
# =============================================================================
{ inputs, nixpkgs }:

let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;

  # fast-track-nix's own inputs merged with the consumer's inputs — mirrors
  # the merge that lib.mkFlake performs so all framework modules receive the
  # inputs they were authored against.
  mergedInputs = inputs.ft-home.inputs // inputs;

  # Path to ft-home's consumer NixOS module hub.
  # Resolved relative to this file: tests/vm/../../modules/nixos.
  consumerModules = ../../modules/nixos;
in
{
  # Wraps runNixOSTest with node.specialArgs so every node's NixOS module
  # system receives `inputs` at specialArgs scope — available when `imports`
  # lists are evaluated, unlike _module.args which is part of the config
  # fixed-point and causes infinite recursion when referenced in `imports`.
  # recursiveUpdate preserves any other node.* or node.specialArgs.* fields
  # the caller may have set.
  mkTest =
    spec:
    pkgs.testers.runNixOSTest (
      nixpkgs.lib.recursiveUpdate spec {
        node.specialArgs.inputs = mergedInputs;
      }
    );

  # ---------------------------------------------------------------------------
  # baseConfig: framework modules only.
  # Use for tests targeting fast-track-nix modules.
  # ---------------------------------------------------------------------------
  baseConfig =
    { ... }:
    {
      imports = [ inputs.ft-home.nixosModules.default ];
      # disko-btrfs: hardware-dependent disk layout, no VM test.
      # gaming: unconditionally imports jovian-nixos, whose overlay.nix /
      #   workarounds.nix set nixpkgs.overlays at normal priority — collides
      #   with nixpkgs/read-only.nix (types.unique) activated by runNixOSTest.
      #   Exempt from VM tests per CLAUDE.md (too heavyweight: Steam, Jovian).
      disabledModules = [
        "${inputs.ft-home}/modules/nixos/hardware/disko-btrfs.nix"
        "${inputs.ft-home}/modules/nixos/profiles/gaming.nix"
      ];
      ft.core.stateVersion = "25.05";
      ft.user.initialPasswords.admin = "test";
      hardware.bluetooth.enable = false;
    };

  # ---------------------------------------------------------------------------
  # consumerBaseConfig: framework + ft-home consumer modules.
  # Use for tests targeting modules in ft-home/modules/nixos/.
  # ---------------------------------------------------------------------------
  consumerBaseConfig =
    { lib, ... }:
    {
      imports = [
        inputs.ft-home.nixosModules.default
        consumerModules
      ];
      disabledModules = [
        "${inputs.ft-home}/modules/nixos/hardware/disko-btrfs.nix"
        "${inputs.ft-home}/modules/nixos/profiles/gaming.nix"
        # stylix NixOS: unconditionally imports inputs.stylix.nixosModules.stylix
        # which sets nixpkgs.overlays — same read-only.nix conflict as gaming.
        # Theming is not tested in VMs.
        "${consumerModules}/system/stylix.nix"
      ];
      ft.core.stateVersion = "25.05";
      ft.user.initialPasswords.admin = "test";
      hardware.bluetooth.enable = false;
      # ft.apps has default = true in the consumer module hub; disable in the
      # shared base so individual tests opt in explicitly and VMs stay lean.
      ft.apps.enable = lib.mkDefault false;
    };
}
