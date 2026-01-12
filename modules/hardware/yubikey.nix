{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.modules.hardware.yubikey;
in
{
  options.modules.hardware.yubikey = {
    enable = lib.mkEnableOption "YubiKey support and PAM integration";
  };

  config = lib.mkIf cfg.enable {
    # Install required tools
    environment.systemPackages = with pkgs; [
      yubikey-manager # Provides 'ykman'
      yubico-piv-tool # For SSH/PIV management
      pam_u2f # Bridge between YubiKey and Linux Login
    ];

    # Enable Smart Card Daemon (Required for ykman and GPG)
    services.pcscd.enable = true;

    # Udev rules allow non-root users to interact with the key
    services.udev.packages = [ pkgs.yubikey-personalization ];

    # PAM Configuration for Login and Sudo
    security.pam.services = {
      login.u2fAuth = true;
      sudo.u2fAuth = true;
      sddm.u2fAuth = true;
      cosmic-greeter.u2fAuth = true;
      cosmic-lock.u2fAuth = true;
    };

    # Prompt user to touch the key (visual feedback)
    security.pam.u2f.settings = {
      cue = true;
      interactive = true;
    };
  };
}
