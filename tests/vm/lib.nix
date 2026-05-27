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
# can evaluate correctly inside the test’s NixOS module system.
#
# disko-btrfs is excluded via disabledModules: it references inputs inside
# its `imports` list, which causes infinite recursion when inputs is provided
# through _module.args. Disk layout is hardware-dependent and has no VM test.
# =============================================================================
{ inputs }:

let
  # fast-track-nix’s own inputs merged with the consumer’s inputs — mirrors
  # the merge that lib.mkFlake performs so all framework modules receive the
  # inputs they were authored against.
  mergedInputs = inputs.ft-home.inputs // inputs;

  # Path to ft-home’s consumer NixOS module hub.
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
      # disko-btrfs uses inputs in its imports list; _module.args causes
      # infinite recursion there. Disk layout is hardware-dependent and
      # excluded from VM smoke tests.
      disabledModules = [ "${inputs.ft-home}/modules/nixos/hardware/disko-btrfs.nix" ];
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
      disabledModules = [ "${inputs.ft-home}/modules/nixos/hardware/disko-btrfs.nix" ];
      _module.args.inputs = mergedInputs;
      ft.system.core.stateVersion = "25.05";
      ft.users.initialPasswords.admin = "test";
      hardware.bluetooth.enable = false;
      # ft.apps has default = true in the consumer module hub; disable in the
      # shared base so individual tests opt in explicitly and VMs stay lean.
      ft.apps.enable = lib.mkDefault false;
    };
}
