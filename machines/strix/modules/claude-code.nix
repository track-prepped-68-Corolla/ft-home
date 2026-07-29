{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
let
  cfg = config.ft.claudeCode;
  lemonade = config.hardware.amd-npu.lemonade;
in
{
  options.ft.claudeCode = {
    enable = lib.mkEnableOption "Claude Code CLI" // {
      description = "Installs Claude Code (via numtide/llm-agents.nix) and points it at strix's local Lemonade server (ft.amdAi) instead of the Anthropic API.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.ft.amdAi.enable;
        message = "ft.claudeCode requires ft.amdAi.enable so the Lemonade server it talks to actually exists.";
      }
    ];

    nix.settings = {
      extra-substituters = lib.mkDefault [ "https://cache.numtide.com" ];
      extra-trusted-public-keys = lib.mkDefault [
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];
    };

    environment.systemPackages = [
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    ];

    # Lemonade serves an Anthropic Messages-compatible API at its server
    # root (Claude Code appends /v1/messages itself, same as it does for
    # api.anthropic.com). Always dial loopback here regardless of
    # hardware.amd-npu.lemonade.host — that option is the *bind* address
    # (0.0.0.0, so the docker microVM can also reach it), not a usable
    # client target. Lemonade has no auth, so the key just has to be
    # present — Claude Code refuses to start without one.
    environment.variables = {
      ANTHROPIC_BASE_URL = lib.mkDefault "http://127.0.0.1:${toString lemonade.port}";
      ANTHROPIC_API_KEY = lib.mkDefault "lemonade-local";
    };
  };
}
