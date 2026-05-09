{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# YUBIKEY INTEGRATION MODULE
# ------------------------------------------------------------------------------
# This module enables comprehensive YubiKey support for various authentication
# methods, including U2F/FIDO2 for login, sudo, and display managers. It installs
# necessary tools and configures PAM for seamless YubiKey integration.
#
# SECURITY NOTE:
# The `u2f_mapping` should contain your YubiKey's U2F registration string. This
# example hardcodes it for simplicity. For production environments, consider
# managing this with `sops-nix` or ensuring appropriate file permissions.
################################################################################

let
  cfg = config.ft.hardware.yubikey;

  # IMPORTANT: Replace this with your actual YubiKey U2F registration string.
  # You can generate this using 'pamu2fcfg -u <username> > ~/.config/Yubico/u2f_keys'
  # and then manually place the content here or refer to a sops-nix secret.
  myU2FAuth = "joe:MMWc0ZbVifMF3Ah0YM3NLnt4xQKLZY75LuZH5LzElyOXheEMiFjC8s0dxFaKMxRvkpBOqz3uIeksC6VcwNF7FQ==,MINo8SZhJxCR+UO9JNJMwKx/Bi+/8TvSOHFCYLLTWhZotMiikV5aAHRKuGV4liqWGVjRdQ==,es256,+presence";

  # Write the U2F mapping to a file that PAM can read.
  u2f_mapping = pkgs.writeText "u2f-mapping" ''
    ${myU2FAuth}
  '';
in
{
  options.ft.hardware.yubikey = {
    enable = lib.mkEnableOption "YubiKey support and PAM integration";

    # Optionally allow setting the U2F mapping directly or via sops-nix.
    # This provides flexibility for managing the U2F registration string.
    u2fMapping = lib.mkOption {
      type = lib.types.str;
      default = myU2FAuth;
      description = "The U2F registration string for the YubiKey. Should ideally be a sops secret.";
    };
  };

  config = lib.mkIf cfg.enable {
    # 1. Install YubiKey Management Tools
    # These packages provide utilities for configuring and managing your YubiKey.
    environment.systemPackages = with pkgs; [
      yubikey-manager # GUI and CLI tool for YubiKey management
      yubico-piv-tool # PIV (Personal Identity Verification) tool
      pam_u2f # PAM module for U2F/FIDO2 authentication
    ];

    # 2. Enable PCSC Daemon for Smart Card Communication
    # Pcscd is necessary for the system to communicate with the YubiKey as a smart card.
    services.pcscd.enable = true;

    # 3. Udev Rules for YubiKey
    # These udev rules ensure that the YubiKey is properly recognized and permissions are set.
    services.udev.packages = [ pkgs.yubikey-personalization ];

    # 4. PAM (Pluggable Authentication Modules) Configuration
    # This configures various system services to use YubiKey for authentication.
    security.pam.services = {
      login.u2fAuth = true; # For console login
      sudo.u2fAuth = true; # For sudo authentication
      sddm.u2fAuth = true; # For SDDM display manager
      cosmic-greeter.u2fAuth = true; # For COSMIC greeter
      cosmic-lock.u2fAuth = true; # For COSMIC lock screen
    };

    # 5. U2F PAM Module Settings
    # Global settings for the pam_u2f module.
    security.pam.u2f.settings = {
      cue = true; # Show a prompt to touch the YubiKey
      interactive = true; # Allow interactive prompts
      control = "sufficient"; # If YubiKey auth succeeds, no further modules are checked.
      authfile = pkgs.writeText "u2f-mapping" cfg.u2fMapping; # Use the configured U2F mapping
    };
  };
}
