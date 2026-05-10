{
  description = "NixOS configuration consuming the ft-home framework";

  inputs = {
    ft-home.url = "github:track-prepped-68-corolla/ft-home/generator-fix";

    # Pin directly to nixos-unstable so packages come from Hydra's binary cache.
    # The generator merges consumer inputs on top of ft-home's, so this nixpkgs
    # takes precedence over ft-home's potentially stale lock.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.follows = "ft-home/home-manager";
  };

  outputs = inputs @ { ft-home, ... }:
    ft-home.lib.mkFlake inputs;
}
