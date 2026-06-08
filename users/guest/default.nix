{ ... }:

{
  imports = [
    ../../modules/home
  ];

  # --- IDENTITY ---
  home.username = "guest";
  ft.core.stateVersion = "25.05";

  programs.git = {
    enable = true;
    userName = "guest";
    userEmail = "guest@fasttrack.os";
    delta.enable = true;
  };
}
