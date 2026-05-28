{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ft."local-ai";
  llamaPort = toString cfg.llamafile.port;
  hermesPort = toString cfg.hermes.port;
  hermesExec =
    if cfg.hermes.execPath != "" then cfg.hermes.execPath else "/home/${cfg.user}/.local/bin/hermes";
in
{
  meta.description = "Local AI stack: llamafile (OpenAI-compatible LLM server) + AnythingLLM (RAG/agent chat UI) + optional hermes-agent companion CLI, all wired together as systemd services.";

  options.ft."local-ai" = {
    user = lib.mkOption {
      type = lib.types.str;
      default = config.ft.user.mainUser;
      description = "User under which llamafile and hermes-agent run. Must own the model files.";
    };

    llamafile = {
      execPath = lib.mkOption {
        type = lib.types.str;
        description = "Absolute path to the llamafile (or llamafile-thin) binary.";
        example = "/home/joe/Documents/llamafile-0.10.1-thin";
      };
      modelPath = lib.mkOption {
        type = lib.types.str;
        description = "Absolute path to the GGUF model file.";
        example = "/home/joe/Documents/Qwen3.5-27B.Q6_K.gguf";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
        description = "Port for the llamafile OpenAI-compatible API.";
      };
      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra flags passed to llamafile.";
        example = [ "--server" "--ctx-size" "32768" "--n-gpu-layers" "99" ];
      };
    };

    hermes = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Run hermes-agent dashboard as a companion service.";
      };
      execPath = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Absolute path to the hermes binary. Empty defaults to ~/.local/bin/hermes.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 8642;
        description = "Port for the hermes API server.";
      };
      apiKey = lib.mkOption {
        type = lib.types.str;
        default = "local";
        description = "API key for the Hermes API server.";
      };
    };

    anythingllm = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 3001;
        description = "Port exposed for the AnythingLLM web UI.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.podman.enable = lib.mkDefault true;
    virtualisation.oci-containers.backend = lib.mkDefault "podman";

    systemd.services.llamafile = {
      description = "llamafile LLM API server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = pkgs.writeShellScript "llamafile-start" ''
          export PATH="${pkgs.gzip}/bin:${pkgs.coreutils}/bin:$PATH"
          exec ${lib.escapeShellArg cfg.llamafile.execPath} \\
            -m ${lib.escapeShellArg cfg.llamafile.modelPath} \\
            --port ${llamaPort} \\
            --host 127.0.0.1 \\
            ${lib.escapeShellArgs cfg.llamafile.extraArgs}
        '';
        User = cfg.user;
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    systemd.services.hermes-agent = lib.mkIf cfg.hermes.enable {
      description = "Hermes AI agent dashboard";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "llamafile.service" ];
      environment = {
        OPENAI_BASE_URL = "http://127.0.0.1:${llamaPort}/v1";
        OPENAI_API_KEY = "local";
        API_SERVER_ENABLED = "true";
        API_SERVER_PORT = hermesPort;
        API_SERVER_HOST = "127.0.0.1";
        API_SERVER_KEY = cfg.hermes.apiKey;
      };
      serviceConfig = {
        ExecStart = pkgs.writeShellScript "hermes-start" ''
          exec ${lib.escapeShellArg hermesExec} gateway run
        '';
        User = cfg.user;
        WorkingDirectory = "/home/${cfg.user}";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    virtualisation.oci-containers.containers.anythingllm = {
      image = "mintplexlabs/anythingllm:latest";
      volumes = [ "/opt/containers/anythingllm/storage:/app/server/storage" ];
      environment = {
        STORAGE_DIR = "/app/server/storage";
        SERVER_PORT = toString cfg.anythingllm.port;
      };
      extraOptions = [ "--network=host" ];
    };

    systemd.services.podman-anythingllm.serviceConfig.ExecStartPre =
      "+"
      + pkgs.writeShellScript "anythingllm-mkdir" ''
        ${pkgs.coreutils}/bin/mkdir -p /opt/containers/anythingllm/storage
        ${pkgs.coreutils}/bin/chown -R ${cfg.user} /opt/containers/anythingllm
      '';

    systemd.tmpfiles.rules = [
      "d /opt/containers 0775 root root -"
      "d /opt/containers/anythingllm 0775 root root -"
      "d /opt/containers/anythingllm/storage 0775 ${cfg.user} - -"
    ];

    networking.firewall.allowedTCPPorts = [ cfg.anythingllm.port ];
  };
}
