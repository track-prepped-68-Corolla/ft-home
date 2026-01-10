{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.modules.system.nh;

  # --- DYNAMIC PRE-FLIGHT LOGIC ---
  # This snippet is injected into the scripts.
  # 1. It uses 'nix eval' to look at the FLAKE_DIR (which has your staged changes).
  # 2. It queries the configuration for the current hostname.
  # 3. It extracts the list of images and pulls them interactively.
  preFlightLogic = ''
    echo "--- 🐳 Container Pre-Flight Check ---"

    HOST=$(hostname)

    echo "   Evaluating container config for host: $HOST..."


    CONTAINER_JSON=$(nix eval --json --extra-experimental-features "nix-command flakes" \
      "$FLAKE_DIR#nixosConfigurations.$HOST.config.virtualisation.oci-containers.containers" 2>/dev/null)

    if [ $? -ne 0 ]; then
      echo "⚠️  Could not evaluate container config. Skipping pre-pull."
      echo "   (This usually happens if the flake is broken or hostname doesn't match)"
    else
      # Parse the JSON to get a list of image strings
      IMAGES=$(echo "$CONTAINER_JSON" | ${pkgs.jq}/bin/jq -r '.[].image')
      
      if [ -z "$IMAGES" ]; then
        echo "   No containers found."
      else
        for img in $IMAGES; do
          echo "   ⬇️  Pulling: $img"
          sudo ${pkgs.podman}/bin/podman pull "$img"
        done
      fi
    fi
    echo "✅ Containers ready."
    echo ""
  '';

  formatCmd = ''
    echo "--- ✨ Formatting ---"
    ${pkgs.findutils}/bin/find "$FLAKE_DIR" -name "*.nix" -exec ${pkgs.nixfmt-rfc-style}/bin/nixfmt {} +
  '';

  # --- Script 1: sys-test ---
  sysTestScript = pkgs.writeShellScriptBin "sys-test" ''
    set -e
    FLAKE_DIR="${cfg.flakeDir}"

    ${formatCmd}

    echo "--- 🛠️  Staging ---"
    ${pkgs.git}/bin/git -C "$FLAKE_DIR" add .

    echo "--- 📄 Source Code Changes (Delta) ---"
    ${pkgs.git}/bin/git -C "$FLAKE_DIR" diff --cached | ${pkgs.delta}/bin/delta

    # INJECTED: Runs against the STAGED flake, so it sees your new edits immediately.
    ${preFlightLogic}

    echo "--- 🧪 Running Test ---"
    ${pkgs.nh}/bin/nh os test "$FLAKE_DIR" --ask
    echo "✅ Test complete. Reboot to revert."
  '';

  # --- Script 2: sys-update ---
  sysUpdateScript = pkgs.writeShellScriptBin "sys-update" ''
    set -e
    FLAKE_DIR="${cfg.flakeDir}"

    ${formatCmd}

    echo "--- 🛠️  Staging ---"
    ${pkgs.git}/bin/git -C "$FLAKE_DIR" add .

    echo "--- 🔍 Previewing Build ---"
    ${pkgs.nh}/bin/nh os test "$FLAKE_DIR" --dry

    echo ""
    echo "--- 📄 Source Code Changes (Delta) ---"
    ${pkgs.git}/bin/git -C "$FLAKE_DIR" diff --cached | ${pkgs.delta}/bin/delta

    echo ""
    read -p "Apply and commit? [y/N]: " choice
    if [[ "$choice" =~ ^[yY]$ ]]; then
      
      # INJECTED: Pulls images right before the switch.
      ${preFlightLogic}

      echo "--- 🚀 Switching ---"
      ${pkgs.nh}/bin/nh os switch "$FLAKE_DIR"

      echo "--- 💾 Committing ---"
      read -p "Commit message: " msg
      ${pkgs.git}/bin/git -C "$FLAKE_DIR" commit -m "$msg"
      echo "✅ Update Complete!"
    else
      echo "🛑 Cancelled."
    fi
  '';

  # --- Script 3: sys-down ---
  sysDownScript = pkgs.writeShellScriptBin "sys-down" ''
    set -e
    FLAKE_DIR="${cfg.flakeDir}"
    echo "--- ⬇️  Pulling updates ---"
    ${pkgs.git}/bin/git -C "$FLAKE_DIR" pull --rebase --autostash

    echo "--- 📄 Incoming Changes (Delta) ---"
    ${pkgs.git}/bin/git -C "$FLAKE_DIR" diff HEAD@{1}..HEAD | ${pkgs.delta}/bin/delta

    # INJECTED: Pulls whatever just came down from git
    ${preFlightLogic}

    echo "--- 🚀 Building and Switching ---"
    ${pkgs.nh}/bin/nh os switch "$FLAKE_DIR" --ask
    echo "✅ System updated!"
  '';

in
{
  options.modules.system.nh = {
    enable = mkEnableOption "nh helper, standardized scripts, and formatting";

    flakeDir = mkOption {
      type = types.str;
      default = "/home/joe/git/nixos-config";
      description = "The absolute path to your NixOS flake directory.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.nh
      pkgs.nvd
      pkgs.nix-output-monitor
      pkgs.nixfmt-rfc-style
      pkgs.findutils
      pkgs.delta
      pkgs.jq
      pkgs.podman
      sysTestScript
      sysUpdateScript
      sysDownScript
    ];

    environment.sessionVariables = {
      NH_FLAKE = cfg.flakeDir;
    };

    environment.shellAliases = {
      try = "sys-test";
      up = "sys-update";
      down = "sys-down";
      cl = "nh clean all";
    };
  };
}
