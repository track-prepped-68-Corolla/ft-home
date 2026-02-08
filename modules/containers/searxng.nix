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
    enable = mkEnableOption "SearXNG container with Sops integration (No Redis)";

    port = mkOption {
      type = types.port;
      default = 6080;
      description = "The host port to bind SearXNG to.";
    };
  };

  config = mkIf cfg.enable {

    # 1. Secrets Management
    # Ensure your 'searxng_env' file contains: SEARXNG_SECRET_KEY=<random_string>
    sops.secrets."searxng_env" = {
      restartUnits = [ "podman-searxng.service" ];
    };

    # 2. Firewall: Allow Podman containers to use the host's DNS resolver
    # We use extraInputRules for nftables compatibility (fixes the "unexpected +" error)
    networking.firewall.extraInputRules = ''
      iifname "podman*" tcp dport 53 accept
      iifname "podman*" udp dport 53 accept
    '';

    # 3. Network Initialization
    systemd.services.init-searxng-network = {
      description = "Create network for SearXNG";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.podman}/bin/podman network create ${networkName} --ignore";
      };
      wantedBy = [ "multi-user.target" ];
      before = [ "podman-searxng.service" ];
    };

    # 4. OCI Containers
    virtualisation.oci-containers.containers = {

      searxng = {
        image = "docker.io/searxng/searxng:latest";
        autoStart = true;
        ports = [ "${toString cfg.port}:8080" ];

        # Inject the secret key from sops
        environmentFiles = [ config.sops.secrets."searxng_env".path ];

        environment = {
          # Keep the Base URL and Bind Address
          SEARXNG_BASE_URL = "http://localhost:${toString cfg.port}/";
          SEARXNG_BIND_ADDRESS = "0.0.0.0";
        };

        # MOUNT THE CONFIG FILE DIRECTLY
        volumes = [
          "${pkgs.writeText "searxng-settings.yml" ''
            # inheret the defaults so we don't break search engines
            use_default_settings: true

            server:
              # CRITICAL: Disable the limiter to stop 403 errors on local network
              limiter: false
              image_proxy: false
              # Secret key is loaded from environment variable SEARXNG_SECRET_KEY automatically

            search:
              # CRITICAL: Explicitly allow JSON for OpenWebUI
              formats:
                - html
                - json
          ''}:/etc/searxng/settings.yml"
        ];

        extraOptions = [
          "--network=${networkName}"
          "--dns=1.1.1.1"
          "--cap-drop=ALL"
          "--cap-add=CHOWN"
          "--cap-add=SETGID"
          "--cap-add=SETUID"
          "--cap-add=DAC_OVERRIDE"
          "--cap-add=NET_BIND_SERVICE"
          "--cap-add=NET_RAW"
        ];
      };
    };
  };
}
