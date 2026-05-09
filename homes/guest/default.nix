{ config, pkgs, ... }:

################################################################################
# HOME MANAGER CONFIGURATION ("guest" user)
# ------------------------------------------------------------------------------
# The Command Center for the "guest" user.
#
# ARCHITECTURE:
# We import ONLY the 'home-modules' hub.
# Because the Hub imports 'home-core.nix' and all modules, we don't need
# to specify anything else here except WHO we are and WHAT we want enabled.
################################################################################

{
  # ----------------------------------------------------------------------------
  # 1. THE PLATFORM IMPORT
  # ----------------------------------------------------------------------------
  imports = [
    ../../home-modules
  ];

  # ----------------------------------------------------------------------------
  # 2. IDENTITY
  # ----------------------------------------------------------------------------
  # 'home-core' uses this to automatically set homeDirectory to /home/guest
  home.username = "guest";

  programs.git = {
    enable = true;
    userName = "guest";
    userEmail = "guest@fasttrack.os";
    delta.enable = true; # Use the aesthetic diff tool from our terminal module
  };

  # ----------------------------------------------------------------------------
  # 3. FEATURE FLAGS
  # ----------------------------------------------------------------------------
  # Turn on the features we want for this specific user.

  # Enable the Container Stack (Podman, Lazydocker, Distrobox)
  #ft.containers.enable = true;

  # (Terminal is enabled by default via the Hub)
}
