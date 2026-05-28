{
  config,
  pkgs,
  lib,
  ...
}:

################################################################################
# DEFAULT APPLICATIONS MODULE
################################################################################

let
  cfg = config.ft.apps;
in
{
  meta = {
    description = "Installs the consumer's default system-wide application suite (ripgrep, fd, fzf, zoxide, eza, bat, lazygit, obsidian, brave, trufflehog, etc.) and enables the Tailscale daemon. Disable to strip all consumer-specific packages from the system closure.";
    default = true;
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      nixos-generators
      direnv
      sops
      wget
      curl
      unzip
      bottom
      duf
      tldr
      perl
      nodejs
      obsidian
      just
      trufflehog

      ripgrep
      fd
      fzf
      zoxide
      eza
      bat

      git
      lazygit

      tmux

      micro

      brave
    ];

    services.tailscale.enable = true;
  };
}
