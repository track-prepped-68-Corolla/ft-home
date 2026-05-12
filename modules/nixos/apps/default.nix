{
  config,
  pkgs,
  lib,
  ...
}:

################################################################################
# DEFAULT APPLICATIONS MODULE
# ------------------------------------------------------------------------------
# System-wide applications and utilities common across all hosts.
# Note: user-specific apps are better managed via Home Manager.
################################################################################

let
  cfg = config.ft.apps;
in
{
  options.ft.apps.enable =
    lib.mkEnableOption "default system applications" // { default = true; };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # System Utilities and Tools
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

      # File System and Search Tools
      ripgrep
      fd
      fzf
      zoxide
      eza
      bat

      # Version Control
      git
      lazygit

      # Terminal Multiplexer
      tmux

      # Text Editors
      micro

      # Browser
      brave
    ];

    services.tailscale.enable = true;
  };
}
