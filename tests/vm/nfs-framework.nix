{ inputs, nixpkgs }:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) baseConfig specialArgs;
in
{
  # ft.services.nfs: systemd automount unit is generated for the configured mount.
  # A real NFS server is not required — only the unit file is verified.
  vm-nfs-framework-load = pkgs.testers.runNixOSTest {
    name = "ft-nfs-framework-load";
    inherit specialArgs;
    nodes.machine =
      { ... }:
      {
        imports = [ baseConfig ];
        ft.services.nfs = {
          enable = true;
          mounts.media = {
            remotePath = "fileserver:/share/media";
            mountPoint = "/mnt/test";
          };
        };
      };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      # Unit name: systemd-escape --path /mnt/test -> mnt-test
      machine.succeed("systemctl cat mnt-test.automount")
      machine.succeed("systemctl is-enabled mnt-test.automount")
    '';
  };
}
