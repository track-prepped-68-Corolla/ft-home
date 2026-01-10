{
  description = "NixOS Configuration";

  inputs = {
    # --- Core ---
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- Hardware & System ---
    nixos-hardware.url = "github:track-prepped-68-Corolla/nixos-hardware";

    # [NEW] CachyOS Kernel (Release Branch = Stable + Cached)
    # We use the release branch to ensure we get the pre-built binaries
    nix-cachyos = {
      url = "github:xddxdd/nix-cachyos-kernel/release";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence.url = "github:nix-community/impermanence";
    jovian-nixos.url = "github:jovian-experiments/jovian-nixos";

    # --- Desktop & Theming ---
    #    nixos-cosmic.url = "github:lilyinstarlight/nixos-cosmic";

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    catppuccin.url = "github:catppuccin/nix";
    catppuccin.inputs.nixpkgs.follows = "nixpkgs";

    stylix.url = "github:nix-community/stylix";
    stylix.inputs.nixpkgs.follows = "nixpkgs";

    # --- Applications ---
    #nixvim = {
    # url = "github:nix-community/nixvim";
    # inputs.nixpkgs.follows = "nixpkgs";
    #};
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      # 1. SHARED ARGUMENTS
      sharedArgs = {
        inherit inputs;
        inherit (inputs)
          catppuccin
          home-manager
          jovian-nixos
          nixos-hardware
          nix-cachyos
          ;
      };

      # 2. SHARED MODULES
      sharedModules = [
        # The Hub
        ./modules/default.nix

        # External Modules
        inputs.home-manager.nixosModules.default
        inputs.sops-nix.nixosModules.sops
        inputs.catppuccin.nixosModules.catppuccin
        inputs.stylix.nixosModules.stylix
        #inputs.nixos-cosmic.nixosModules.default
        inputs.jovian-nixos.nixosModules.default

        # --- GLOBAL CONFIGURATION ---
        # Converted to a function to access 'inputs' for the overlay
        (
          { inputs, ... }:
          {

            config = {
              # 1. System Basics
              system.stateVersion = "25.05";
              nixpkgs.config.allowUnfree = true;

              nixpkgs.overlays = [ inputs.nix-cachyos.overlays.pinned ];

              # --- CONNECTIVITY ---
              networking.networkmanager.enable = true;
              hardware.bluetooth = {
                enable = true;
                powerOnBoot = true;
              };

              # 2. Localization
              time.timeZone = "America/New_York";
              i18n.defaultLocale = "en_US.UTF-8";

              # 3. Bootloader
              boot.loader = {
                systemd-boot.enable = false;
                grub = {
                  enable = true;
                  efiSupport = true;
                  device = "nodev";
                  useOSProber = true;
                };
                efi.canTouchEfiVariables = true;
              };

              # 4. Nix Settings & Caches
              nix.settings = {
                experimental-features = [
                  "nix-command"
                  "flakes"
                ];

                # [NEW] Binary Cache for CachyOS Kernels
                # Without this, you will compile the kernel for 4+ hours.
                substituters = [
                  "https://cosmic.cachix.org/"
                  "https://attic.xuyh0120.win/lantian" # CachyOS Maintainer Cache
                ];

                trusted-public-keys = [
                  "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
                  "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" # Key for CachyOS
                ];
              };

              # 5. Home Manager Integration
              home-manager.sharedModules = [
                inputs.plasma-manager.homeModules.plasma-manager
              ];
            };
          }
        )
      ];
    in
    {
      nixosConfigurations = {
        # --- Host: ROG (ASUS Flow) ---
        rog = nixpkgs.lib.nixosSystem {
          specialArgs = sharedArgs;
          modules = sharedModules ++ [
            ./hosts/rog/default.nix
            inputs.nixos-hardware.nixosModules.asus-flow-gz301vu
          ];
        };

        # --- Host: Thinkpad (T14 AMD) ---
        thinkpad = nixpkgs.lib.nixosSystem {
          specialArgs = sharedArgs;
          modules = sharedModules ++ [
            ./hosts/thinkpad/default.nix
            inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14-amd-gen2
          ];
        };

        # --- Host: Talos ---
        talos = nixpkgs.lib.nixosSystem {
          specialArgs = sharedArgs;
          modules = sharedModules ++ [
            ./hosts/talos/default.nix
          ];
        };

        # --- Host: Strix (Strix Halo) ---
        strix = nixpkgs.lib.nixosSystem {
          specialArgs = sharedArgs;
          modules = sharedModules ++ [
            ./hosts/strix/default.nix
          ];
        };
      };
    };
}
