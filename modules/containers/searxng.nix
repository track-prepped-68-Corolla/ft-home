{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.modules.containers.searxng;
  networkName = "searxng-net";
in
{
  options.modules.containers.searxng = {
    enable = mkEnableOption "SearXNG container with Redis and Sops integration";

    port = mkOption {
      type = types.port;
      default = 6080;
      description = "The host port to bind SearXNG to.";
    };
  };

  config = mkIf cfg.enable {

    sops.secrets."searxng_env" = {
      restartUnits = [ "podman-searxng.service" ]; # Restart container when secret changes
    };

    # 2. Network Initialization
    systemd.services.init-searxng-network = {
      description = "Create network for SearXNG";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.podman}/bin/podman network create ${networkName} --ignore";
      };
      wantedBy = [ "multi-user.target" ];
      before = [
        "podman-searxng.service"
        "podman-searxng-redis.service"
      ];
    };

    # 3. OCI Containers
    virtualisation.oci-containers.containers = {

      searxng-redis = {
        image = "docker.io/library/redis:alpine";
        cmd = [
          "redis-server"
          "--save"
          ""
          "--appendonly"
          "no"
        ];
        autoStart = true;
        extraOptions = [ "--network=${networkName}" ];
      };

      searxng = {
        image = "docker.io/searxng/searxng:latest";
        autoStart = true;
        ports = [ "${toString cfg.port}:8080" ];

        # Inject the sops secret file directly
        environmentFiles = [ config.sops.secrets."searxng_env".path ];

        environment = {
          SEARXNG_BASE_URL = "http://localhost:${toString cfg.port}/";
          SEARXNG_REDIS_URL = "redis://searxng-redis:6379/0";
        };

        extraOptions = [
          "--network=${networkName}"
          "--dns=1.1.1.1"
          "--cap-add=NET_BIND_SERVICE" # Allows binding to ports (vital)
          "--cap-add=NET_RAW" # Allows ping and raw sockets (vital for some network checks)
        ];
      };
    };
  };
}
