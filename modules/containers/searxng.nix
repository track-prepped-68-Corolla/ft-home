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

        # CRITICAL FIX: Map host port (6080) to container's listening port (8080)
        ports = [ "${toString cfg.port}:8080" ];

        # Inject the sops secret file directly
        environmentFiles = [ config.sops.secrets."searxng_env".path ];

        environment = {
          SEARXNG_BASE_URL = "http://localhost:${toString cfg.port}/";

          # CRITICAL: Allow JSON output for OpenWebUI
          SEARXNG_FORMATS = "html,json";

          # CRITICAL: Disable rate limiter since we removed Redis
          # This fixes the "403 Forbidden" error on local networks
          SEARXNG_LIMITER = "false";

          # Ensure it listens on all interfaces so the port map works
          SEARXNG_BIND_ADDRESS = "0.0.0.0";
        };

        extraOptions = [
          "--network=${networkName}"

          # CRITICAL FIX: Explicit DNS to bypass local resolver issues
          "--dns=1.1.1.1"

          # CRITICAL FIX: Capabilities required for networking & ping
          "--cap-drop=ALL"
          "--cap-add=CHOWN"
          "--cap-add=SETGID"
          "--cap-add=SETUID"
          "--cap-add=DAC_OVERRIDE"
          "--cap-add=NET_BIND_SERVICE" # Required to bind ports
          "--cap-add=NET_RAW" # Required for ping/DNS checks
        ];
      };
    };
  };
}
