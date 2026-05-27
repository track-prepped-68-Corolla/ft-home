{ inputs, nixpkgs }:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  inherit (import ./lib.nix { inherit inputs; }) consumerBaseConfig;
in
{
  # ft.nfs (consumer): systemd automount unit is generated for the configured mount.
  # A real NFS server is not required — only the unit file is verified.
  vm-nfs-consumer-load = pkgs.testers.runNixOSTest {
    name = "ft-nfs-consumer-load";
    nodes.machine =
      { ... }:
      {
        imports = [ consumerBaseConfig ];
        ft.nfs = {
          enable = true;
          mounts.media = {
            remotePath = "fileserver:/share/media";
            mountPoint = "/mnt/test";
          };
        };
      };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("systemctl cat mnt-test.automount")
      machine.succeed("systemctl is-enabled mnt-test.automount")
    '';
  };
}
