{
  config,
  pkgs,
  lib,
  ...
}:

################################################################################
# DEFAULT APPLICATIONS MODULE
# ------------------------------------------------------------------------------
# This module defines a set of essential applications and utilities that are
# commonly used across different NixOS configurations. It aims to provide a
# robust baseline of tools for development, system management, and general use.
#
# Note: Many applications are better managed via Home Manager for user-specific
# configurations. This module focuses on system-wide installations.
################################################################################

{
  config = {
    environment.systemPackages = with pkgs; [
      # System Utilities and Tools
      nixos-generators # Tool for generating various NixOS artifacts
      direnv # Environment switcher for shell
      #tailscale
      sops # Secrets management (used with sops-nix)
      wget # Network downloader
      curl # Transfer data from or to a server
      unzip # Decompress zip archives
      bottom # Interactive process viewer
      duf # Disk Usage/Free Utility
      tldr # Simplified man pages
      perl # Practical Extraction and Report Language
      nodejs # JavaScript runtime
      obsidian
      just
      trufflehog

      # File System and Search Tools
      ripgrep # Super-fast grep alternative
      fd # Simple, fast and user-friendly alternative to find
      fzf # A command-line fuzzy finder
      zoxide # A smarter cd command
      eza # A modern replacement for 'ls'
      bat # A 'cat' clone with wings (syntax highlighting, Git integration)

      # Version Control
      git # The famous version control system
      lazygit # A simple terminal UI for git commands

      # Terminal Multiplexer
      tmux # Terminal multiplexer

      # Text Editors (Basic system-wide)
      micro # A modern and intuitive terminal-based text editor
      #neovim           # A Vim-fork focused on extensibility and usability
      # a browser
      brave
    ];

    services.tailscale.enable = true;

    #programs.nix-index-database.comma.enable = true;
    #programs.nix-index.enable = true;
    #programs.command-not-found.enable = false;

    #services.tailscale.extraUpFlags = [ "--operator=${config.mainuser}" ];
  };
}
