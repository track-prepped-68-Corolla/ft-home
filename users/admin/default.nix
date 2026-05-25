{ ... }:

{
  imports = [
    ../../modules/home
  ];

  # --- IDENTITY ---
  home.username = "admin";
  ft.home.core.stateVersion = "24.05";

  programs.git = {
    enable = true;
    userName = "admin";
    userEmail = "admin@fasttrack.os";
    delta.enable = true;
  };
}
