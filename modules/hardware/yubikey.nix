{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.modules.hardware.yubikey;

  # Your specific hardware key details
  myUsername = "joe";
  myPublicKey = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIDgZCe1UZA1E7bCpTWz5NUMHlGUq16nOobSJ2LyyZCP2AAAABHNzaDo=";

  # Create the mapping file in the Nix Store
  # This makes it globally readable, fixing the COSMIC Greeter permission issue
  u2f_mapping = pkgs.writeText "u2f-mapping" ''
    ${myUsername}:${myPublicKey}
  '';
in
{
  options.modules.hardware.yubikey = {
    enable = lib.mkEnableOption "YubiKey support and PAM integration";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      yubikey-manager
      yubico-piv-tool
      pam_u2f
    ];

    services.pcscd.enable = true;
    services.udev.packages = [ pkgs.yubikey-personalization ];

    security.pam.services = {
      login.u2fAuth = true;
      sudo.u2fAuth = true;
      cosmic-greeter.u2fAuth = true;
      cosmic-lock.u2fAuth = true;
    };

    security.pam.u2f.settings = {
      cue = true;
      interactive = true;
      control = "sufficient";

      # Crucial: Tells PAM to interpret the key as an SSH key
      sshformat = true;

      # Points to the Nix Store file we generated above
      authfile = "${u2f_mapping}";
    };
  };
}
