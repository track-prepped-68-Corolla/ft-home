# =============================================================================
# VM Test Shared Library
# =============================================================================
#
# Provides two base NixOS module configs for use in all VM smoke tests:
#
#   baseConfig         — framework modules only
#   consumerBaseConfig — framework + ft-home consumer modules (modules/nixos/)
#
# mergedInputs replicates what lib.mkFlake does so framework modules that
# reference inputs.* at import time (sops-nix, nix-index-database, etc.)
# can evaluate correctly inside the test's NixOS module system.
#
# disko-btrfs and gaming are excluded via disabledModules: both are
# hardware-dependent with no VM smoke test. gaming.nix also references
# inputs inside its `imports` list, which causes infinite recursion when
# inputs is provided through _module.args rather than specialArgs.
# =============================================================================
{ inputs }:

let
  # fast-track-nix's own inputs merged with the consumer's inputs — mirrors
  # the merge that lib.mkFlake performs so all framework modules receive the
  # inputs they were authored against.
  mergedInputs = inputs.ft-home.inputs // inputs;

  # Path to ft-home's consumer NixOS module hub.
  # Resolved relative to this file: tests/vm/../../modules/nixos.
  consumerModules = ../../modules/nixos;
in
{
  # ---------------------------------------------------------------------------
  # baseConfig: framework modules only.
  # Use for tests targeting fast-track-nix modules.
  # ---------------------------------------------------------------------------
  baseConfig =
    { ... }:
    {
      imports = [ inputs.ft-home.nixosModules.default ];
      # disko-btrfs: hardware-dependent disk layout, no VM test.
      # gaming: GPU/gaming hardware-dependent, no VM test; also uses inputs
      # in its imports list which causes infinite recursion with _module.args.
      disabledModules = [
        "${inputs.ft-home}/modules/nixos/hardware/disko-btrfs.nix"
        "${inputs.ft-home}/modules/nixos/profiles/gaming.nix"
      ];
      _module.args.inputs = mergedInputs;
      ft.system.core.stateVersion = "25.05";
      ft.users.initialPasswords.admin = "test";
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
      ];
      _module.args.inputs = mergedInputs;
      ft.system.core.stateVersion = "25.05";
      ft.users.initialPasswords.admin = "test";
      hardware.bluetooth.enable = false;
      # ft.apps has default = true in the consumer module hub; disable in the
      # shared base so individual tests opt in explicitly and VMs stay lean.
      ft.apps.enable = lib.mkDefault false;
    };
}
