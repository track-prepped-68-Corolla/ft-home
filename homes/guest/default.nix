# =============================================================================
# guest — Home Manager Configuration
# =============================================================================
#
# Discovered by lib/generator.nix at homes/guest/default.nix and becomes
# homeConfigurations.guest@x86_64-linux (and any other active arch).
#
# Restricted guest user. Gets the full terminal stack (enabled by default
# via ft.terminal.enable) and git. Add ft.* toggles or packages following
# the same pattern as homes/joe/default.nix.
# =============================================================================
{ config, pkgs, ... }:

{
  imports = [
    ../../modules/home
  ];

  # --- IDENTITY ---
  home.username = "guest";

  programs.git = {
    enable = true;
    userName = "guest";
    userEmail = "guest@fasttrack.os";
    delta.enable = true;
  };
}
