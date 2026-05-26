{ inputs, nixpkgs }:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) consumerBaseConfig;
in
{
  # ft.rclone (consumer): rclone is on PATH and FUSE user_allow_other is set.
  vm-rclone-load = pkgs.testers.runNixOSTest {
    name = "ft-rclone-load";
    nodes.machine =
      { ... }:
      {
        imports = [ consumerBaseConfig ];
        ft.rclone.enable = true;
      };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("which rclone")
      machine.succeed("grep -q user_allow_other /etc/fuse.conf")
    '';
  };
}
