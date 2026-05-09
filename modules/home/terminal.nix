{
  config,
  pkgs,
  lib,
  ...
}:

################################################################################
# TERMINAL & SHELL MODULE
# ------------------------------------------------------------------------------
# "Batteries Included" Terminal.
# THE PHILOSOPHY:
# We use Neovim as the default editor, but we inject "Normie Bindings" (Ctrl+S/C/V)
# via Lua so beginners can edit files without panicking.
################################################################################

{
  # ----------------------------------------------------------------------------
  # 1. ENVIRONMENT VARIABLES
  # ----------------------------------------------------------------------------
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # ----------------------------------------------------------------------------
  # 2. THE TERMINAL: Kitty
  # ----------------------------------------------------------------------------
  programs.kitty = {
    enable = true;
    settings = {
      scrollback_lines = 10000;
      enable_audio_bell = false;
      update_check_interval = 0;
      window_padding_width = 4;
    };
  };

  # ----------------------------------------------------------------------------
  # 3. THE SHELL: Zsh
  # ----------------------------------------------------------------------------
  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    enableCompletion = true;
    initContent = "source ${config.home.homeDirectory}/git/ft-home/home/dotfiles/zsh/.zshrc";
  };

  # ----------------------------------------------------------------------------
  # 5. SUPPORTING PACKAGES
  # ----------------------------------------------------------------------------
  home.packages = with pkgs; [
    # Foundation
    git
    curl
    wget
    gnutar
    gzip
    unzip
    zip
    psmisc
    which
    tree
    # System Info
    fastfetch
    cpufetch
    # Modern Core
    ghostty
    kitty
    neovim
    bat
    eza
    btop
    fd
    ripgrep
    dust
    # Workflow
    yazi
    lazygit
    tealdeer
    jq
    gping
    # Internet
    browsh
    ddgr
  ];

  # ----------------------------------------------------------------------------
  # STARSHIP (Linked for easy editing)
  # ----------------------------------------------------------------------------
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    # Disable the built-in settings so it doesn't conflict with our symlink
    # settings = {};
  };

  home.file.".config/starship.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/git/ft-home/home/dotfiles/starship/starship.toml";

  # ----------------------------------------------------------------------------
  # GHOSTTY (Linked for easy editing)
  # ----------------------------------------------------------------------------

  home.file.".config/ghostty/config".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/git/ft-home/home/dotfiles/ghostty/config";

  # ----------------------------------------------------------------------------
  # SHELL INTEGRATIONS
  # ----------------------------------------------------------------------------
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
}
