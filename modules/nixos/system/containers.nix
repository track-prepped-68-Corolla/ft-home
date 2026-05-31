{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.ft.containers;
in
{
  options.ft.containers = {
    enable = lib.mkEnableOption "the FT container stack (Podman, Distrobox, Komodo)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      docker-compose
      distrobox
      podman-compose
    ];

    virtualisation = {
      podman = {
        enable = true;
        dockerCompat = true;
        dockerSocket.enable = true;
        defaultNetwork.settings.dns_enabled = true;
      };

      oci-containers.backend = "podman";

      oci-containers.containers = {
        # --- MongoDB ---
        komodo-db = {
          image = "mongo:latest";
          volumes = [ "/opt/containers/komodo/mongodb:/data/db" ];
          extraOptions = [ "--network=host" ];
        };

        # --- Komodo Core ---
        komodo = {
          image = "ghcr.io/mbecker20/komodo:latest";
          ports = [ "8120:9120" ];
          volumes = [
            "/opt/containers/komodo/config.toml:/config/config.toml"
            "/opt/containers/komodo/stacks:/etc/komodo/stacks"
            "/opt/containers/komodo/repos:/repo-cache"
            "/opt/containers/komodo/syncs:/syncs"
          ];
          dependsOn = [ "komodo-db" ];
          environment = {
            TZ = config.time.timeZone;
            KOMODO_CONFIG_PATH = "/config/config.toml";
          };
          extraOptions = [ "--network=host" ];
        };

        # --- Periphery ---
        periphery = {
          image = "ghcr.io/mbecker20/periphery:latest";
          environment = {
            PERIPHERY_PASSKEYS = "default-passkey-changeme";
          };
          volumes = [
            "/run/podman/podman.sock:/var/run/docker.sock"
            "/opt/containers/komodo:/etc/komodo"
          ];
          extraOptions = [
            "--network=host"
            "--privileged"
          ];
        };
      };
    };

    systemd.tmpfiles.rules = [
      "d /opt/containers 0775 root root -"
      "f /opt/containers/komodo/config.toml 0664 root root -"
    ];

    networking.firewall.allowedTCPPorts = [
      8120
      8121
      9120
      27017
    ];
    users.users.${config.ft.users.mainUser}.extraGroups = [
      "podman"
      "docker"
    ];
  };
}
