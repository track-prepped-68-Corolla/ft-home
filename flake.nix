{
  description = "NixOS configuration — consumer of ft-home";

  inputs = {
    nixpkgs.url          = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url   = "github:nixos/nixpkgs/nixos-25.11";
    nixos-hardware.url   = "github:NixOS/nixos-hardware/master";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ft-home = {
      url = "github:track-prepped-68-corolla/ft-home";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    Disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-facter = {
      url = "github:numtide/nixos-facter";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    jovian-nixos = {
      url = "github:jovian-experiments/jovian-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: inputs.ft-home.lib.mkFlake inputs;
}
