{ pkgs, config, lib, ... }:

let
  cfg = config.ft.autoprovision;
in
{
  options.ft.autoprovision.enable =
    lib.mkEnableOption "user home manager auto-provisioning" // { default = true; };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      # 1. The provisioning wrapper
      (pkgs.writeShellScriptBin "hm-template-wrapper" ''
        USERNAME=$1
        REPO="/etc/nixos"

        if [ -z "$USERNAME" ]; then exit 1; fi
        if [ -d "$REPO/homes/$USERNAME" ]; then exit 0; fi

        echo "Creating new profile from generic template..."
        cp -r "$REPO/homes/generic" "$REPO/homes/$USERNAME"

        # Guarantee write access and ownership for the non-wheel user
        chown -R "$USERNAME:users" "$REPO/homes/$USERNAME"
        chmod -R u+rwX "$REPO/homes/$USERNAME"

        # Stage it so the initial switch works
        git -C "$REPO" add "homes/$USERNAME"
      '')

      # 2. A git wrapper so non-wheel users can stage NEW files they create later
      (pkgs.writeShellScriptBin "hm-git-add" ''
        # Runs as root; strictly limited to git add within the user's directory.
        REPO="/etc/nixos"
        git -C "$REPO" add "$REPO/homes/$SUDO_USER"
      '')

      # 3. The GUI trigger
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
