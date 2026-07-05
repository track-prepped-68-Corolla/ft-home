{ ... }:
{
  ft.liveIso.enable = true;

  ft.liveIso.authorizedKeys = [
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIDgZCe1UZA1E7bCpTWz5NUMHlGUq16nOobSJ2LyyZCP2AAAABHNzaDo= track-prepped-68-Corolla@protonmail.com"
  ];

  ft.core.stateVersion = "25.05";
  nixpkgs.hostPlatform = "x86_64-linux";

  # ft.cli now defaults to true (ergonomics on real consumer machines); a live
  # installer image has no consumer repo checked out anywhere, so ft.repoPath
  # is meaningless here.
  ft.cli.enable = false;
}
