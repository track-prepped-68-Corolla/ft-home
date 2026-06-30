# =============================================================================
# ft.secrets — personal sops secret bundle (consumer module)
# =============================================================================
# A single drop-in that declares this operator's personal sops secrets and wires
# them into the machine. Enable per machine with `ft.secrets.enable = true` plus
# the per-category toggles below — no file to copy: this module is auto-imported
# on every machine via `../../modules/nixos`, it just stays inert until enabled.
#
# The encrypted values live in var/secrets/secrets.yaml and are decrypted at
# activation to /run/secrets (and /run/secrets-for-users for login hashes).
# Nothing secret is ever baked into the Nix store / closure.
#
# Builds on ft.sops (asserted below) — that module provides the age identity
# (SSH host key, optionally TPM/YubiKey) and points sops at secrets.yaml. Secrets
# already owned by a feature module (e.g. ft.tailscale's tailscale/authkey) are
# intentionally NOT redeclared here.
#
# Two wiring styles:
#   * passwords / sshKeys -> fully wired (hashedPasswordFile set; private key
#                            placed at ~/.ssh/id_ed25519).
#   * wifi / apiTokens    -> declared + exposed at /run/secrets/<...>; final
#                            consumption is backend/service-specific and done
#                            where that service is configured, e.g.:
#
#       networking.wireless.secretsFile =
#         config.sops.secrets."wifi/<ssid>".path;   # wpa_supplicant
#       services.foo.environmentFile =
#         config.sops.secrets."tokens/<name>".path;
#
# BEFORE enabling on a machine: add the secret keys to secrets.yaml and make the
# machine a recipient in .sops.yaml (sops updatekeys), or activation fails to
# decrypt.
{ lib, config, ... }:
let
  cfg = config.ft.secrets;
  # Derive SSH key placement from each user's configured home, not a fixed
  # /home/<u> — respects custom home directories (e.g. /root, service users).
  userHome = u: config.users.users.${u}.home;
  userGroup = u: config.users.users.${u}.group;
in
{
  options.ft.secrets = {
    enable = lib.mkEnableOption "personal sops secret bundle" // {
      description = "Declares this operator's personal sops secrets (login password hashes, WiFi PSKs, API tokens, SSH user keys) and wires them into the machine. Requires ft.sops.enable. Each category is opt-in via its own option; encrypted values live in var/secrets/secrets.yaml and are decrypted at activation, never baked into the closure.";
    };

    passwords = {
      enable = lib.mkEnableOption "login password hashes from sops" // {
        description = "Sets users.users.<user>.hashedPasswordFile to the sops secret passwords/<user> for each user in `passwords.users`, so login hashes come from the encrypted store instead of a plaintext initialPassword. Also unblocks users.mutableUsers = false.";
      };
      users = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Users whose hashedPasswordFile is sourced from the sops secret passwords/<user>. Each name must have a corresponding passwords/<user> entry in secrets.yaml.";
      };
    };

    sshKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Users for whom an SSH private key is placed at ~/.ssh/id_ed25519 (mode 0600, owned by the user) from the sops secret ssh/<user>. The matching authorized public key is handled separately (ft.ssh). Each name must have an ssh/<user> entry in secrets.yaml.";
    };

    wifi = {
      enable = lib.mkEnableOption "WiFi PSK secrets" // {
        description = "Declares a sops secret wifi/<ssid> for each SSID in `wifi.networks`, exposed at /run/secrets/wifi/<ssid>. Consumption is backend-specific (wpa_supplicant secretsFile, NetworkManager, iwd) and wired where the network backend is configured — see the module header for an example.";
      };
      networks = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "WiFi SSIDs to declare a wifi/<ssid> PSK secret for. Each must have a wifi/<ssid> entry in secrets.yaml.";
      };
    };

    apiTokens = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Names of API tokens / service credentials to declare as sops secrets tokens/<name>, exposed at /run/secrets/tokens/<name> (mode 0400). Reference the decrypted path where the consuming service is configured. Each must have a tokens/<name> entry in secrets.yaml.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.ft.sops.enable;
        message = "ft.secrets requires ft.sops.enable = true (it provides the age identity and the sops secrets file).";
      }
    ];

    sops.secrets =
      # passwords/<user> — needed before user creation, so neededForUsers.
      # Gated by passwords.enable so the category honours its own opt-in.
      lib.optionalAttrs cfg.passwords.enable (
        lib.listToAttrs (
          map (u: lib.nameValuePair "passwords/${u}" { neededForUsers = true; }) cfg.passwords.users
        )
      )
      # ssh/<user> — placed at the user's ~/.ssh/id_ed25519.
      // lib.listToAttrs (
        map (
          u:
          lib.nameValuePair "ssh/${u}" {
            owner = u;
            mode = "0600";
            path = "${userHome u}/.ssh/id_ed25519";
          }
        ) cfg.sshKeys
      )
      # wifi/<ssid> — exposed at the default /run/secrets path.
      // lib.optionalAttrs cfg.wifi.enable (
        lib.listToAttrs (map (s: lib.nameValuePair "wifi/${s}" { }) cfg.wifi.networks)
      )
      # tokens/<name> — exposed at the default /run/secrets path (0400).
      // lib.listToAttrs (map (n: lib.nameValuePair "tokens/${n}" { mode = "0400"; }) cfg.apiTokens);

    # hashedPasswordFile wiring for each password user (mkDefault so a machine can
    # still override a specific user's password source). Gated by passwords.enable.
    users.users = lib.optionalAttrs cfg.passwords.enable (
      lib.listToAttrs (
        map (
          u:
          lib.nameValuePair u {
            hashedPasswordFile = lib.mkDefault config.sops.secrets."passwords/${u}".path;
          }
        ) cfg.passwords.users
      )
    );

    # Ensure ~/.ssh exists (0700, owned by the user) before sops drops the key in.
    # Path + group come from the user's own config, not a hardcoded /home/<u> or group.
    systemd.tmpfiles.rules = map (
      u: "d ${userHome u}/.ssh 0700 ${u} ${userGroup u} - -"
    ) cfg.sshKeys;
  };
}
