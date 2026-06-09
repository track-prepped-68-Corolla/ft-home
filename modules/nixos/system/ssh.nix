{
  config,
  lib,
  ...
}:

let
  cfg = config.ft.ssh;
in
{
  options.ft.ssh = {
    enable = lib.mkEnableOption "key-only SSH daemon" // {
      description = "Enables OpenSSH, forces password and keyboard-interactive authentication off, and provisions `authorizedKeys` for `user`. Password auth cannot be re-enabled while this module is active.";
    };

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH public keys to add to the authorized_keys list for `ft.ssh.user`.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Local user account that receives the authorized keys. The account must be declared elsewhere (e.g. via `ft.users.*`).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.openssh.enable = lib.mkDefault true;

    services.openssh.settings = {
      # Security invariant: this module's purpose is key-only SSH.
      # Re-enabling passwords would silently defeat the security guarantee.
      PasswordAuthentication = lib.mkForce false;
      # Keyboard-interactive can fall back to password on some PAM stacks.
      KbdInteractiveAuthentication = lib.mkForce false;
    };

    users.users.${cfg.user}.openssh.authorizedKeys.keys = lib.mkDefault cfg.authorizedKeys;
  };
}
