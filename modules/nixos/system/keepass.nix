{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ft.keepass;
in
{
  # Define your custom flag
  options.ft.keepass = {
    enable = lib.mkEnableOption "KeePassXC as the primary keyring and secret service";
  };

  # Apply configuration if the flag is true
  config = lib.mkIf cfg.enable {

    # 1. Install KeePassXC system-wide
    environment.systemPackages = with pkgs; [
      keepassxc
    ];

    # 2. Disable conflicting secret services
    # GNOME Keyring is often auto-enabled by display managers (like SDDM/GDM) or DEs.
    services.gnome.gnome-keyring.enable = lib.mkForce false;

    # If you use KDE Plasma, uncomment these to disable KWallet:
    # security.pam.services.kwallet.enableKwallet = lib.mkForce false;

    # 3. (Optional) If you plan to use KeePassXC as your SSH agent,
    # disable the default NixOS SSH agent to prevent socket conflicts.
    # programs.ssh.startAgent = lib.mkForce false;
  };
}
