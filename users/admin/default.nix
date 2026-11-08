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
    settings.user = {
      name = "admin";
      email = "admin@fasttrack.os";
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };
}
