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

  # Trim the default-on framework modules that make no sense in a throwaway
  # provisioning ISO. The image gets the whole modules/nixos tree, so anything
  # whose enable defaults to true is baked in unless turned off here.
  #
  # ft.admin bakes an "admin" wheel account with initialPassword = "changeme"
  # into the distributable image — an unwanted known credential. Root autologs
  # in on the console and SSH password auth is off, so the ISO needs no extra
  # admin account.
  ft.admin.enable = false;

  # nix-index ships a prebuilt database in the closure — pure bloat on an
  # installer that is discarded after provisioning.
  ft.nixIndex.enable = false;

  # Bluetooth and CUPS/Avahi printing come from ft.core but have no place on a
  # bootstrap ISO. NetworkManager (also from ft.core) is kept — it is useful
  # for bringing up the link before running nixos-anywhere.
  hardware.bluetooth.enable = false;
  services.printing.enable = false;
}
