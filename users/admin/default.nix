{ ... }:

{
  imports = [
    ../../modules/home
  ];

  # --- IDENTITY ---
  home.username = "admin";
  ft.core.stateVersion = "25.05";

  programs.git = {
    enable = true;
    userName = "admin";
    userEmail = "admin@fasttrack.os";
    delta.enable = true;
  };
}
