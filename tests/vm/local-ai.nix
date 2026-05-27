{ inputs, nixpkgs }:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) consumerBaseConfig mkTest;
in
{
  # ft.services.localAi (consumer): llamafile and AnythingLLM systemd unit files
  # are generated. A real LLM binary or model is not required — only unit
  # existence is verified.
  vm-local-ai-load = mkTest {
    name = "ft-local-ai-load";
    nodes.machine =
      { ... }:
      {
        imports = [ consumerBaseConfig ];
        ft.services.localAi = {
          enable = true;
          llamafile = {
            # Real store path so ExecStart resolves; exits immediately (no-op).
            execPath = "${pkgs.coreutils}/bin/true";
            modelPath = "/dev/null";
          };
          hermes.enable = false;
        };
      };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("systemctl cat llamafile.service")
      machine.succeed("systemctl cat podman-anythingllm.service")
    '';
  };
}
