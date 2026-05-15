{ config, lib, pkgs, ... }:

let
  cfg = config.ft.services.localAi;
  llamaPort = toString cfg.llamafile.port;
  hermesPort = toString cfg.hermes.port;
  hermesExec =
    if cfg.hermes.execPath != ""
    then cfg.hermes.execPath
    else "/home/${cfg.user}/.local/bin/hermes";
in
{
  options.ft.services.localAi = {
    enable = lib.mkEnableOption "local AI stack: llamafile → Hermes agent → AnythingLLM UI" // {
      description = "Runs a three-tier local AI stack: llamafile serves a GGUF model as an OpenAI-compatible API; Hermes Agent wraps it as a tool-calling agent with its own OpenAI-compatible HTTP API; AnythingLLM provides the chat UI backed by Hermes. Configure LLM provider in AnythingLLM's web UI after first boot: use 'Generic OpenAI' pointing at http://localhost:${hermesPort}/v1.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = config.mainuser;
      description = "User under which llamafile and Hermes run. Must own the model files and have Hermes installed (pip install hermes-agent).";
    };

    llamafile = {
      execPath = lib.mkOption {
        type = lib.types.str;
        description = "Absolute path to the llamafile (or llamafile-thin) binary.";
        example = "/home/joe/models/llamafile-0.8.18";
      };
      modelPath = lib.mkOption {
        type = lib.types.str;
        description = "Absolute path to the GGUF model file.";
        example = "/home/joe/models/Qwen3-235B-A22B-128K-UD-Q2_K_XL.gguf";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
        description = "Port for the llamafile OpenAI-compatible API (loopback only; consumed by Hermes).";
      };
      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra flags passed to llamafile, e.g. --ctx-size, --n-gpu-layers.";
        example = [
          "--ctx-size"
          "32768"
          "--n-gpu-layers"
          "99"
        ];
      };
    };

    hermes = {
      execPath = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Absolute path to the hermes binary. Empty string defaults to ~/.local/bin/hermes under the service user.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 9119;
        description = "Port for the Hermes web API server. AnythingLLM connects here for chat completions.";
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

    systemd.services.hermes-agent = {
      description = "Hermes AI agent web API server";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "llamafile.service"
      ];
      environment = {
        # Point Hermes at the local llamafile backend.
        # ~/.hermes/.env is loaded by Hermes with override=true, so place any
        # persistent overrides there rather than fighting this value.
        OPENAI_BASE_URL = "http://127.0.0.1:${llamaPort}/v1";
        OPENAI_API_KEY = "local";
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
      # host network so the container can reach Hermes on 127.0.0.1
      extraOptions = [ "--network=host" ];
    };

    # Ensure storage dir exists before Podman tries to mount it.
    systemd.services.podman-anythingllm.serviceConfig.ExecStartPre =
      "+" + pkgs.writeShellScript "anythingllm-mkdir" ''
        ${pkgs.coreutils}/bin/mkdir -p /opt/containers/anythingllm/storage
        ${pkgs.coreutils}/bin/chown -R ${cfg.user}:${cfg.user} /opt/containers/anythingllm
      '';

    systemd.tmpfiles.rules = [
      "d /opt/containers 0775 root root -"
      "d /opt/containers/anythingllm 0775 root root -"
      "d /opt/containers/anythingllm/storage 0775 ${cfg.user} ${cfg.user} -"
    ];

    networking.firewall.allowedTCPPorts = [ cfg.anythingllm.port ];
  };
}
