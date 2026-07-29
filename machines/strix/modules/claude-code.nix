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
  system = pkgs.stdenv.hostPlatform.system;
  homeDir = "/home/${config.ft.users.mainUser}";

  # Claude Code Router is the glue: it speaks Claude Code's Anthropic-format
  # requests on one side and Lemonade's OpenAI-compatible
  # /api/v1/chat/completions on the other. Lemonade has no auth, but both
  # Claude Code Router and Claude Code itself refuse to start without a
  # non-empty key, hence the dummy value.
  routerConfig = {
    Providers = [
      {
        name = "lemonade";
        api_base_url = "http://127.0.0.1:${toString lemonade.port}/api/v1/chat/completions";
        api_key = "lemonade-local";
        models = [ cfg.model ];
      }
    ];
    Router = {
      default = "lemonade,${cfg.model}";
    };
  };
  routerConfigFile = pkgs.writeText "claude-code-router-config.json" (builtins.toJSON routerConfig);
in
{
  options.ft.claudeCode = {
    enable = lib.mkEnableOption "Claude Code CLI" // {
      description = "Installs Claude Code + Claude Code Router (via numtide/llm-agents.nix) and routes Claude Code through Claude Code Router to strix's local Lemonade server (ft.amdAi) instead of the Anthropic API. Run `ccr code` (not `claude` directly) to get the routed session.";
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Model name exactly as registered in Lemonade (see `lemonade-server list`). Required whenever ft.claudeCode.enable is true — Claude Code Router needs a concrete model to route to, and there is no sane machine-wide default for this.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.ft.amdAi.enable;
        message = "ft.claudeCode requires ft.amdAi.enable so the Lemonade server it routes to actually exists.";
      }
      {
        assertion = cfg.model != "";
        message = "ft.claudeCode.model must be set to a model name already loaded in Lemonade (see `lemonade-server list`).";
      }
    ];

    nix.settings = {
      extra-substituters = lib.mkDefault [ "https://cache.numtide.com" ];
      extra-trusted-public-keys = lib.mkDefault [
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];
    };

    environment.systemPackages = [
      inputs.llm-agents.packages.${system}.claude-code
      inputs.llm-agents.packages.${system}.claude-code-router
    ];

    # Declarative — ~/.claude-code-router/config.json becomes a Nix store
    # symlink, so it always matches this module and can't drift from hand edits.
    systemd.tmpfiles.rules = [
      "d ${homeDir}/.claude-code-router 0755 ${config.ft.users.mainUser} users -"
      "L+ ${homeDir}/.claude-code-router/config.json - - - - ${routerConfigFile}"
    ];
  };
}
