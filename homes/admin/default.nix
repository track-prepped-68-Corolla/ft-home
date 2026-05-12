# =============================================================================
# admin — Home Manager Configuration
# =============================================================================
#
# Discovered by lib/generator.nix at homes/admin/default.nix and becomes
# homeConfigurations.admin@x86_64-linux (and any other active arch).
#
# Minimal admin/maintenance user. Gets the full terminal stack (enabled by
# default via ft.terminal.enable) and git. Add ft.* toggles or packages
# following the same pattern as homes/joe/default.nix.
# =============================================================================
{ config, pkgs, ... }:

{
  imports = [
    ../../modules/home
  ];

  # --- IDENTITY ---
  home.username = "admin";

  programs.git = {
    enable = true;
    userName = "admin";
    userEmail = "admin@fasttrack.os";
    delta.enable = true;
  };
}
