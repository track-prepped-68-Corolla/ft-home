_:

{
  imports = [
    ../../modules/home
  ];

  # --- IDENTITY ---
  home.username = "guest";

  programs.git = {
    enable = true;
    userName = "guest";
    userEmail = "guest@fasttrack.os";
    delta.enable = true;
  };
}
