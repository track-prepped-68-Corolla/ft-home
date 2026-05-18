{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

let
  # --- CONSTANTS ---
  # These groups are applied to every user created by this module.
  commonGroups = [
    "networkmanager" # Manage Wifi/Ethernet
    "podman" # Run containers without root
    "lp"
    "scanner" # Printing and scanning
    "video"
    "render" # Hardware acceleration (GPU)
  ];
in
{
  # --- THE API (Options) ---
  # These are the "knobs" you turn in your machine files (e.g., machines/spec/default.nix).
  options = {
    mainuser = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "The primary username other modules (like Home Manager) will target.";
    };

    superUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra users who get sudo (wheel) access.";
    };

    normalUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Standard users with no administrative privileges.";
    };
  };

  # --- THE IMPLEMENTATION (Config) ---
  config = {

    # 1. ENABLE YUBIKEY / U2F AUTHENTICATION
    security.pam.u2f = {
      enable = true;
      settings = {
        cue = true; # Tells you to tap the key
        interactive = true;
        control = "sufficient";
        authFile = pkgs.writeText "u2f_keys" ''
          admin:umYt1X/qG0dA0eXySg2gujsVMu8hrZpifCf1rynFdb47NZzWGPLJ1db8R5Jgg8C4PxgjsVtYZoNxeUKD4YbKcA==,1XgVi7a4BpLBwWW6x17CU9VguEwoqAEJCg7LvnlgAQpcsFOBuiAl40jAiO//dvaDN
        '';
      };
    };

    security.pam.services = {
      login.u2fAuth = true;
      sudo.u2fAuth = true;
    };

    users.users = lib.mkMerge [

      # 1. THE PERMANENT ADMIN (Safety Net)
      # This user is hardcoded. It is always present on every system you build.
      {
        admin = {
          isNormalUser = true;
          extraGroups = commonGroups ++ [ "wheel" ]; # 'wheel' = sudo access
          initialPassword = lib.mkDefault "snp";
          #openssh.authorizedKeys.keys = [
          # "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAINTWBO+wJvD/8Dili8rdo9fNvNLxYnzTZxv90Y2AK0WfAAAADXNzaDpmYXN0dHJhY2s= ssh:fasttrack"
          #];
          shell = pkgs.zsh;
        };
      }

      # 2. EXTRA SUPER USERS
      # This loop creates any user listed in 'superUsers'.
      # We filter out 'admin' to prevent the system from crashing if you list it twice.
      (lib.genAttrs (lib.filter (u: u != "admin") config.superUsers) (user: {
        isNormalUser = true;
        extraGroups = commonGroups ++ [ "wheel" ];
        initialPassword = lib.mkDefault "changeme";
        shell = pkgs.zsh;
      }))

      # 3. NORMAL USERS
      # This loop creates restricted accounts with no sudo access.
      (lib.genAttrs (lib.filter (u: u != "admin") config.normalUsers) (user: {
        isNormalUser = true;
        extraGroups = commonGroups;
        initialPassword = lib.mkDefault "changeme";
        shell = pkgs.zsh;
      }))
    ];
    # --------------------------------------------------------------------------
    # 2. HOME MANAGER AUTOMATION
    # --------------------------------------------------------------------------
    # This logic takes every user defined above and attempts to import their
    # specific Home Manager configuration file.

    home-manager.users =
      lib.genAttrs (lib.unique ([ config.mainuser ] ++ config.superUsers ++ config.normalUsers))
        (
          user:
          # CRITICAL: This assumes your folder structure is standard.
          # nixos/modules/users.nix -> ../../ -> PROJECT ROOT -> users/
          # If this path is wrong, the build will FAIL (which is good for debugging).
          import ../../../home/users/${user}/default.nix
        );

    # --------------------------------------------------------------------------
    # 3. GLOBAL ARGUMENTS
    # --------------------------------------------------------------------------
    # Pass 'inputs' (from flake.nix) to Home Manager.
    # This lets your user configs use inputs.nix-cachyos, inputs.stylix, etc.
    home-manager.extraSpecialArgs = { inherit inputs; };

    # Ensure Home Manager uses the system's package set to save disk space
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
  };
}
