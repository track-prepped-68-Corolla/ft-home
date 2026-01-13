{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.modules.hardware.yubikey;

  myU2FAuth = "joe:MMWc0ZbVifMF3Ah0YM3NLnt4xQKLZY75LuZH5LzElyOXheEMiFjC8s0dxFaKMxRvkpBOqz3uIeksC6VcwNF7FQ==,MINo8SZhJxCR+UO9JNJMwKx/Bi+/8TvSOHFCYLLTWhZotMiikV5aAHRKuGV4liqWGVjRdQ==,es256,+presence";

  u2f_mapping = pkgs.writeText "u2f-mapping" ''
    ${myU2FAuth}
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
      sddm.u2fAuth = true;
      cosmic-greeter.u2fAuth = true;
      cosmic-lock.u2fAuth = true;
    };

    security.pam.u2f.settings = {
      cue = true;
      interactive = true;
      control = "sufficient";

      authfile = "${u2f_mapping}";
    };
  };
}
