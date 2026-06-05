{ inputs, nixpkgs }:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) baseConfig mkTest;
in
{
  vm-ssh-load = mkTest {
    name = "ft-ssh-load";
    nodes.machine =
      { ... }:
      {
        imports = [ baseConfig ];
        ft.ssh = {
          enable = true;
          # Synthetic test key — not a real keypair.
          authorizedKeys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILMOHDUWMJt5VvdV4fMl6Q02RHAklKXjSECEPVTM1xm4 ft-test"
          ];
        };
      };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("sshd.service")
      machine.succeed("grep -q 'PasswordAuthentication no' /etc/ssh/sshd_config")
      machine.succeed("grep -qF 'ssh-ed25519' /etc/ssh/authorized_keys.d/admin")
    '';
  };
}
