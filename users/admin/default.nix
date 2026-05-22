_:

{
  imports = [
    ../../modules/home
  ];

  # --- IDENTITY ---
  home.username = "admin";

  programs.git = {
    enable = true;
    userName = "admin";
    userEmail = "admin@fasttrack.os";
    delta.enable = true;
  };
}
