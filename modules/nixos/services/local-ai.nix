{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ft.services.localAi;
  llamaPort = toString cfg.llamafile.port;
  hermesPort = toString cfg.hermes.port;
  hermesExec =
    if cfg.hermes.execPath != "" then cfg.hermes.execPath else "/home/${cfg.user}/.local/bin/hermes";
in
{
  options.ft.services.localAi = {
    enable = lib.mkEnableOption "local AI stack: llamafile + AnythingLLM" // {
      description = ''
        Runs a local AI stack:

          llamafile  — serves a GGUF model as an OpenAI-compatible API (port ${llamaPort})
          AnythingLLM — RAG/agent chat UI backed by llamafile (port ${toString cfg.anythingllm.port})
          hermes-agent — optional companion CLI agent also pointed at llamafile (port ${hermesPort})

        After first boot, open AnythingLLM at http://localhost:${toString cfg.anythingllm.port},
        configure LLM provider → Generic OpenAI → Base URL: http://localhost:${llamaPort}/v1.

        hermes-agent (dashboard) is available at http://localhost:${hermesPort} for its
        own management UI; it requires a manually built frontend to serve completions
        and is not wired into AnythingLLM by default.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = config.mainuser;
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
        description = "Extra flags passed to llamafile, e.g. --server, --ctx-size, --n-gpu-layers.";
        example = [ "--server" "--ctx-size" "32768" "--n-gpu-layers" "99" ];
      };
    };

    hermes = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Run hermes-agent dashboard as a companion service. Requires hermes installed via pipx.";
      };
      execPath = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Absolute path to the hermes binary. Empty defaults to ~/.local/bin/hermes under the service user.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 9119;
        description = "Port for the hermes dashboard / API server.";
      };
      apiKey = lib.mkOption {
        type = lib.types.str;
        default = "local";
        description = "API key for the Hermes API server (API_SERVER_KEY). Use this same value as the API key in AnythingLLM's Generic OpenAI provider config.";
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
    # Ensure Podman is available even if ft.containers is not enabled.
    virtualisation.podman.enable = lib.mkDefault true;
    virtualisation.oci-containers.backend = lib.mkDefault "podman";

    systemd.services.llamafile = {
      description = "llamafile LLM API server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = pkgs.writeShellScript "llamafile-start" ''
          export PATH="${pkgs.gzip}/bin:${pkgs.coreutils}/bin:$PATH"
          exec ${lib.escapeShellArg cfg.llamafile.execPath} \
            -m ${lib.escapeShellArg cfg.llamafile.modelPath} \
            --port ${llamaPort} \
            --host 127.0.0.1 \
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
        API_SERVER_KEY = cfg.hermes.apiKey;
      };
      serviceConfig = {
        ExecStart = pkgs.writeShellScript "hermes-start" ''
          exec ${lib.escapeShellArg hermesExec} dashboard --port ${hermesPort}
        '';
        User = cfg.user;
        WorkingDirectory = "/home/${cfg.user}";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    virtualisation.oci-containers.containers.anythingllm = {
      image = "mintplexlabs/anythingllm:latest";
      volumes = [
        "/opt/containers/anythingllm/storage:/app/server/storage"
      ];
      environment = {
        STORAGE_DIR = "/app/server/storage";
        SERVER_PORT = toString cfg.anythingllm.port;
      };
      # host network so the container can reach llamafile on 127.0.0.1
      extraOptions = [ "--network=host" ];
    };

    # Ensure storage dir exists before Podman tries to mount it.
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
