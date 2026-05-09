{
  description = "NixOS configuration consuming the ft-home framework";

  inputs = {
    ft-home.url = "github:track-prepped-68-corolla/ft-home/claude/generator-fix";

    # Follow ft-home's nixpkgs and home-manager to avoid duplicate fetches
    nixpkgs.follows = "ft-home/nixpkgs";
    home-manager.follows = "ft-home/home-manager";
  };

  outputs = inputs @ { ft-home, ... }:
    ft-home.lib.mkFlake inputs;
}
