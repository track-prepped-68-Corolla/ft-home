# =============================================================================
# VM Test Shared Library
# =============================================================================
#
# Provides two base NixOS module configs for use in all VM smoke tests:
#
#   baseConfig         — framework modules only
#   consumerBaseConfig — framework + ft-home consumer modules (modules/nixos/)
#
# specialArgs must be passed to every runNixOSTest call so modules that
# reference inputs.* at import time (disko-btrfs, sops-nix, nix-index-database,
# etc.) can evaluate without hitting infinite recursion.  Using _module.args
# instead causes a cycle: imports → inputs → _module.args → config → imports.
#
# mergedInputs replicates what lib.mkFlake does so framework modules that
# reference inputs.* at import time (sops-nix, nix-index-database, etc.)
# can evaluate correctly inside the test's NixOS module system.
# =============================================================================
{ inputs, nixpkgs }:

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
  # specialArgs threads mergedInputs into every node's nixosSystem evaluation
  # as a true special argument (not via _module.args), making inputs available
  # before imports are resolved and avoiding the infinite-recursion trap.
  specialArgs = { inputs = mergedInputs; };

  # ---------------------------------------------------------------------------
  # baseConfig: framework modules only.
  # Use for tests targeting fast-track-nix modules.
  # ---------------------------------------------------------------------------
  baseConfig =
    { ... }:
    {
      imports = [ inputs.ft-home.nixosModules.default ];
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
      ft.system.core.stateVersion = "25.05";
      ft.users.initialPasswords.admin = "test";
      hardware.bluetooth.enable = false;
      # ft.apps has default = true in the consumer module hub; disable in the
      # shared base so individual tests opt in explicitly and VMs stay lean.
      ft.apps.enable = lib.mkDefault false;
    };
}
