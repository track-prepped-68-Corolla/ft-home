{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.containers.ai;
in
{
  options.modules.containers.ai = {
    enable = lib.mkEnableOption "AI Stack (Strix Halo Final)";
    modelPath = lib.mkOption {
      type = lib.types.path;
      default = "/home/joe/models";
    };
    modelName = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
  };

  config = lib.mkIf cfg.enable {

    virtualisation.oci-containers.backend = "podman";

    virtualisation.oci-containers.containers = {

      # 1. THE BACKEND (llama.cpp on Strix Halo)
      llama-cpp = {
        image = "kyuz0/amd-strix-halo-toolboxes:rocm-6.4.4";
        autoStart = true;

        # Performance Flags for Strix Halo
        environment = {
          "HSA_ENABLE_SDMA" = "0";
          "GGML_CUDA_NO_PINNED" = "1";
        };

        entrypoint = "llama-server";

        cmd = [
          "-m"
          "/home/joe/models/dolphin-2.9.2-mixtral-8x22b-Q4_K_M.gguf/dolphin-2.9.2-mixtral-8x22b-Q4_K_M-00001-of-00002.gguf"
          "--host"
          "0.0.0.0"
          "--port"
          "8080"
          "-c"
          "131072"
          "-ngl"
          "99"
          "--no-mmap"
        ];

        # Host Networking: Essential for localhost communication
        extraOptions = [
          "--network=host"
          "--device=/dev/kfd"
          "--device=/dev/dri"
          "--security-opt=label=disable"
          "--no-healthcheck"
        ];

        volumes = [
          "${cfg.modelPath}:/models"
          "/home/joe/containers/rocm:/root/.cache"
        ];
      };

      # 2. THE FRONTEND (OpenWebUI)
      open-webui = {
        image = "ghcr.io/open-webui/open-webui:main";
        autoStart = true;

        environment = {
          "PORT" = "3000";

          # DECLARATIVE CONFIG:
          "ENABLE_OLLAMA_API" = "False"; # <--- Disables the Ollama toggle/search
          "OPENAI_API_BASE_URL" = "http://127.0.0.1:8080/v1"; # <--- Points to llama.cpp
          "OPENAI_API_KEY" = "sk-no-key-required"; # <--- Dummy key to satisfy client

          #"WEBUI_AUTH" = "false";                        # <--- Optional: Skips login screen
        };

        volumes = [ "open-webui-data:/app/backend/data" ];
        extraOptions = [ "--network=host" ];
      };
    };
  };
}
