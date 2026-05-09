{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.ft.lazyvim;

  # UPDATE THIS: The absolute path to the nvim folder inside your nix repo
  nvimConfigPath = "/home/joe/git/ft-home/home/dotfiles/nvim";
in
{
  # 1. Define the boolean flag
  options.ft.lazyvim = {
    enable = lib.mkEnableOption "Custom LazyVim configuration";
  };

  # 2. Apply the configuration ONLY if the flag is true
  config = lib.mkIf cfg.enable {

    home.packages = with pkgs; [
      # Core Editor & Dependencies
      neovim
      git
      gcc
      gnumake
      ripgrep
      fd
      lazygit
      unzip
      wget
      curl
      tree-sitter
      nodejs
      wl-clipboard

      # Python
      pyright
      black
      isort

      # Go
      go
      gopls
      gofumpt

      # Rust
      cargo
      rustc
      rust-analyzer
      rustfmt

      # C / C++
      clang-tools

      # Web & Config & CSS (prettier handles css, json, yaml, markdown)
      marksman
      prettier
      yaml-language-server
      vscode-langservers-extracted # Provides jsonls and cssls

      # XML
      lemminx

      # Nix
      nixd
      nixfmt
    ];

    # Map the dotfiles to ~/.config/nvim out-of-store
    xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink nvimConfigPath;

    home.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };
}
