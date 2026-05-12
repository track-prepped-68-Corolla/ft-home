{ pkgs, config, lib, ... }:

let
  cfg = config.ft.autoprovision;
in
{
  options.ft.autoprovision.enable = lib.mkEnableOption "user home manager auto-provisioning" // {
    default = true;
    description = "Installs three helper scripts (`hm-template-wrapper`, `hm-git-add`, `hm-gui-bootstrap`) and a COSMIC autostart entry that run the first Home Manager switch for new users on their first graphical login. Grants passwordless sudo for the template and git-stage wrappers.";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "hm-template-wrapper" ''
        USERNAME=$1
        REPO="/etc/nixos"

        if [ -z "$USERNAME" ]; then exit 1; fi
        if [ -d "$REPO/homes/$USERNAME" ]; then exit 0; fi

        echo "Creating new profile from generic template..."
        cp -r "$REPO/homes/generic" "$REPO/homes/$USERNAME"

        chown -R "$USERNAME:users" "$REPO/homes/$USERNAME"
        chmod -R u+rwX "$REPO/homes/$USERNAME"

        git -C "$REPO" add "homes/$USERNAME"
      '')

      (pkgs.writeShellScriptBin "hm-git-add" ''
        # Runs as root; strictly limited to git add within the user's directory.
        REPO="/etc/nixos"
        git -C "$REPO" add "$REPO/homes/$SUDO_USER"
      '')

      (pkgs.writeShellScriptBin "hm-gui-bootstrap" ''
        if [ ! -e "$HOME/.local/state/nix/profiles/home-manager" ]; then
          ${pkgs.cosmic-term}/bin/cosmic-term -e ${pkgs.just}/bin/just -f /etc/nixos/autoprovision.just bootstrap-user "$USER"
        fi
      '')
    ];

    environment.etc."xdg/autostart/hm-bootstrap.desktop".text = ''
      [Desktop Entry]
      Name=Home Manager Bootstrap
      Comment=Bootstraps Home Manager on first graphical login
      Exec=hm-gui-bootstrap
      Type=Application
      NoDisplay=true
      Terminal=false
    '';

    security.sudo.extraRules = [
      {
        groups = [ "users" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/hm-template-wrapper";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/hm-git-add";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
