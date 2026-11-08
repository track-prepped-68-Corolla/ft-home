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
    settings.user = {
      name = "guest";
      email = "guest@fasttrack.os";
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };
}
