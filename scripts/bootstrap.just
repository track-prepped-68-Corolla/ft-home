# --- Bootstrap & Provisioning ---

# Initialize git repo and set remote URL.
git-init:
    #!/usr/bin/env bash
    set -e
    _rp() {
      local key="$1" prompt="$2"
      if [ -f "var/git/$key" ]; then cat "var/git/$key"; return; fi
      read -rp "$prompt: " val
      mkdir -p var/git
      printf '%s' "$val" > "var/git/$key"
      echo "$val"
    }
    GIT_NAME=$(_rp "user-name"  "Git user name")
    GIT_EMAIL=$(_rp "user-email" "Git user email")
    GIT_REMOTE=$(_rp "remote"    "Remote URL (e.g. git@github.com:you/nixos-config)")
    git init
    git config user.name  "$GIT_NAME"
    git config user.email "$GIT_EMAIL"
    git remote add origin "$GIT_REMOTE" 2>/dev/null || git remote set-url origin "$GIT_REMOTE"
    mkdir -p var/local
    printf '%s' "$(nix eval --impure --expr 'builtins.currentSystem' --raw)" > var/local/system
    printf '%s' "$PWD" > var/local/repoPath
    git add var/git/ -f var/local/
    git diff --cached --quiet || git commit -m "chore: store git config and local state in var"
    echo ":: Git initialised. Remote: $GIT_REMOTE ::"

# Initialize tailscale config.
tailscale-init:
    #!/usr/bin/env bash
    set -e
    _rp() {
      local key="$1" prompt="$2"
      if [ -f "var/tailscale/$key" ]; then cat "var/tailscale/$key"; return; fi
      read -rp "$prompt: " val
      mkdir -p var/tailscale
      printf '%s' "$val" > "var/tailscale/$key"
      echo "$val"
    }
    TS_TAILNET=$(_rp "tailnet" "Tailscale tailnet name (e.g. example.ts.net)")
    if ! sops --decrypt var/secrets/shared/tailscale.yaml 2>/dev/null | grep -q auth-key; then
      read -rsp "Tailscale auth key (input hidden): " TS_KEY; echo
      printf 'auth-key: "%s"\n' "$TS_KEY" | sops --encrypt --input-type yaml \
        --output var/secrets/shared/tailscale.yaml /dev/stdin
    fi
    git add var/tailscale/ var/secrets/shared/tailscale.yaml
    git diff --cached --quiet || git commit -m "chore: tailscale config"
    echo ":: Tailscale configured for tailnet: $TS_TAILNET ::"

# Scaffold a new machine in machines/<name>/.
add-machine name ip:
    #!/usr/bin/env bash
    set -e
    NAME="{{name}}"
    IP="{{ip}}"
    MACHINE_DIR="machines/${NAME}"
    if [ -d "$MACHINE_DIR" ]; then
      echo ":: Machine ${NAME} already exists at ${MACHINE_DIR} ::"
      exit 0
    fi
    SYSTEM="$(nix eval --impure --expr 'builtins.currentSystem' --raw)"
    mkdir -p var/local
    printf '%s' "$NAME"   > var/local/machineName
    printf '%s' "$SYSTEM" > var/local/system
    mkdir -p "${MACHINE_DIR}/modules"
    mkdir -p "${MACHINE_DIR}/var"
    printf '%s\n' \
      '{ lib, ... }:' \
      '{' \
      '  imports = [' \
      '    ./modules' \
      '    ../../modules/nixos' \
      '  ];' \
      '' \
      "  networking.hostName = \"${NAME}\";" \
      '' \
      '  ft.users = {' \
      '    mainUser = "joe";' \
      '    superUsers = [ "joe" ];' \
      '  };' \
      '  users.users.joe.initialPassword = "nixos";' \
      '  users.mutableUsers = true;' \
      '' \
      '  ft.repoPath = lib.strings.trim (builtins.readFile ../../var/local/repoPath);' \
      '  ft.limine.enable = true;' \
      '  ft.cosmic.enable = true;' \
      '  ft.cli.enable = true;' \
      '' \
      '  ft.mullet = {' \
      '    enable     = true;' \
      '    sourcePath = ../../users/joe/var/mullet.txt;' \
      '  };' \
      '' \
      '  ft.sops = {' \
      '    enable = true;' \
      '    useTPM = true;' \
      '  };' \
      '' \
      '  ft.facter = {' \
      '    enable     = true;' \
      '    reportPath = ./var/facter.json;' \
      '  };' \
      '' \
      '  ft.core.stateVersion = "25.05";' \
      "  nixpkgs.hostPlatform = \"${SYSTEM}\";" \
      '}' \
      > "${MACHINE_DIR}/default.nix"
    printf '%s\n' \
      '{ lib, ... }:' \
      'let' \
      '  allFiles = lib.filesystem.listFilesRecursive ./.;' \
      '  validModules = builtins.filter (' \
      '    path: lib.hasSuffix ".nix" (builtins.toString path) && path != ./default.nix' \
      '  ) allFiles;' \
      'in' \
      '{' \
      '  imports = validModules;' \
      '}' \
      > "${MACHINE_DIR}/modules/default.nix"
    git add "var/local/" "${MACHINE_DIR}/"
    git diff --cached --quiet || git commit -m "bootstrap: scaffold machine ${NAME}"
    echo ":: Machine ${NAME} scaffolded at ${MACHINE_DIR} ::"
    just --justfile "{{justfile()}}" generate-facts "${NAME}" "${IP}"

# Generate SSH host key + derive age pubkey; create var/secrets/.sops.yaml if absent.
secrets-init name:
    #!/usr/bin/env bash
    set -e
    NAME="{{name}}"
    TMPDIR="/tmp/bootstrap-${NAME}"
    SECRETS_DIR="var/secrets"
    SOPS_YAML="${SECRETS_DIR}/.sops.yaml"
    mkdir -p "$TMPDIR" "$SECRETS_DIR"
    if [ ! -f "${TMPDIR}/ssh_host_ed25519_key" ]; then
      ssh-keygen -t ed25519 -N "" -f "${TMPDIR}/ssh_host_ed25519_key" -C "root@${NAME}"
    fi
    AGE_KEY=$(ssh-to-age < "${TMPDIR}/ssh_host_ed25519_key.pub")
    echo ":: Age pubkey for ${NAME}: ${AGE_KEY} ::"
    if [ ! -f "$SOPS_YAML" ]; then
      cat > "$SOPS_YAML" <<SOPSEOF
keys:
  - &${NAME} ${AGE_KEY}

creation_rules:
  - path_regex: var/secrets/.*\.yaml\$
    key_groups:
      - age:
        - *${NAME}
SOPSEOF
      git add "$SOPS_YAML"
      git diff --cached --quiet || git commit -m "bootstrap: initialise sops config for ${NAME}"
      echo ":: Created ${SOPS_YAML} ::"
    else
      echo ":: ${SOPS_YAML} already exists — add this line to the keys section and re-run sops updatekeys ::"
      echo "     - &${NAME} ${AGE_KEY}"
    fi

# SSH into target and collect hardware facts into machines/<name>/var/facter.json.
generate-facts name ip:
    #!/usr/bin/env bash
    set -e
    NAME="{{name}}"
    IP="{{ip}}"
    mkdir -p "machines/${NAME}/var"
    echo ":: Scanning hardware on ${IP} ::"
    ssh "root@${IP}" \
      "nix run github:numtide/nixos-facter -- -o /tmp/facter.json && cat /tmp/facter.json" \
      > "machines/${NAME}/var/facter.json"
    git add "machines/${NAME}/var/facter.json"
    git diff --cached --quiet || git commit -m "bootstrap: hardware facts for ${NAME}"
    echo ":: machines/${NAME}/var/facter.json written ::"

# Install NixOS on target via nixos-anywhere; confirms the OS disk interactively first.
deploy name ip:
    #!/usr/bin/env bash
    set -e
    NAME="{{name}}"
    IP="{{ip}}"
    TMPDIR="/tmp/bootstrap-${NAME}"
    MACHINE_CFG="machines/${NAME}/default.nix"
    # Confirm disk device before formatting — show lsblk output from target.
    CURRENT_DEVICE=$(grep -oP 'device\s*=\s*"\K[^"]+' "$MACHINE_CFG" 2>/dev/null | head -1 || true)
    if [ -n "$CURRENT_DEVICE" ]; then
      echo ":: Disks visible on ${IP} ::"
      ssh "root@${IP}" "lsblk -d -o NAME,SIZE,MODEL,TYPE --noheadings | grep disk" 2>/dev/null || \
        ssh "root@${IP}" "lsblk -d -o NAME,SIZE,TYPE --noheadings" 2>/dev/null || true
      echo ""
      read -rp "OS disk device [${CURRENT_DEVICE}]: " NEW_DEVICE
      NEW_DEVICE="${NEW_DEVICE:-$CURRENT_DEVICE}"
      [[ "$NEW_DEVICE" != /dev/* ]] && NEW_DEVICE="/dev/${NEW_DEVICE}"
      if [ "$NEW_DEVICE" != "$CURRENT_DEVICE" ]; then
        sed -i "s|device = \"${CURRENT_DEVICE}\"|device = \"${NEW_DEVICE}\"|" "$MACHINE_CFG"
        git add "$MACHINE_CFG"
        git diff --cached --quiet || git commit -m "bootstrap: set OS disk to ${NEW_DEVICE} for ${NAME}"
        echo ":: Updated ft.diskBtrfs.device to ${NEW_DEVICE} ::"
      fi
    fi
    EXTRA_FILES=""
    if [ -f "${TMPDIR}/ssh_host_ed25519_key" ]; then
      mkdir -p "${TMPDIR}/etc/ssh"
      cp "${TMPDIR}/ssh_host_ed25519_key"     "${TMPDIR}/etc/ssh/"
      cp "${TMPDIR}/ssh_host_ed25519_key.pub" "${TMPDIR}/etc/ssh/"
      EXTRA_FILES="--extra-files ${TMPDIR}"
    fi
    nixos-anywhere --flake ".#${NAME}" $EXTRA_FILES "root@${IP}"

# Install NixOS on this machine from the live ISO (nixos-anywhere via root@localhost).
deploy-local name:
    #!/usr/bin/env bash
    set -e
    NAME="{{name}}"
    TMPDIR="/tmp/bootstrap-${NAME}"
    MACHINE_CFG="machines/${NAME}/default.nix"
    # Confirm disk device — show lsblk for this machine.
    echo ":: Disks on this machine ::"
    lsblk -d -o NAME,SIZE,MODEL,TYPE --noheadings 2>/dev/null | grep disk || \
      lsblk -d -o NAME,SIZE,TYPE --noheadings 2>/dev/null || true
    echo ""
    CURRENT_DEVICE=$(grep -oP 'device\s*=\s*"\K[^"]+' "$MACHINE_CFG" 2>/dev/null | head -1 || true)
    read -rp "OS disk device [${CURRENT_DEVICE:-/dev/nvme0n1}]: " NEW_DEVICE
    NEW_DEVICE="${NEW_DEVICE:-${CURRENT_DEVICE:-/dev/nvme0n1}}"
    [[ "$NEW_DEVICE" != /dev/* ]] && NEW_DEVICE="/dev/${NEW_DEVICE}"
    if [ -n "$CURRENT_DEVICE" ] && [ "$NEW_DEVICE" != "$CURRENT_DEVICE" ]; then
      sed -i "s|device = \"${CURRENT_DEVICE}\"|device = \"${NEW_DEVICE}\"|" "$MACHINE_CFG"
      git add "$MACHINE_CFG"
      git diff --cached --quiet || git commit -m "bootstrap: set OS disk to ${NEW_DEVICE} for ${NAME}"
      echo ":: Updated ft.diskBtrfs.device to ${NEW_DEVICE} ::"
    fi
    EXTRA_FILES=""
    if [ -f "${TMPDIR}/ssh_host_ed25519_key" ]; then
      mkdir -p "${TMPDIR}/etc/ssh"
      cp "${TMPDIR}/ssh_host_ed25519_key"     "${TMPDIR}/etc/ssh/"
      cp "${TMPDIR}/ssh_host_ed25519_key.pub" "${TMPDIR}/etc/ssh/"
      EXTRA_FILES="--extra-files ${TMPDIR}"
    fi
    nixos-anywhere --flake ".#${NAME}" --phases disko,install --no-reboot $EXTRA_FILES root@localhost

# Full bootstrap: git-init → add-machine (includes generate-facts) → secrets-init → deploy.
bootstrap name ip:
    #!/usr/bin/env bash
    set -e
    just --justfile "{{justfile()}}" git-init 2>/dev/null || true
    just --justfile "{{justfile()}}" add-machine "{{name}}" "{{ip}}"
    just --justfile "{{justfile()}}" secrets-init "{{name}}"
    just --justfile "{{justfile()}}" deploy "{{name}}" "{{ip}}"
    echo ":: Bootstrap complete for {{name}} ::"

# Full local bootstrap (on live ISO): git-init → add-machine → secrets-init → deploy-local.
bootstrap-local name:
    #!/usr/bin/env bash
    set -e
    just --justfile "{{justfile()}}" git-init 2>/dev/null || true
    just --justfile "{{justfile()}}" add-machine "{{name}}" "localhost"
    just --justfile "{{justfile()}}" secrets-init "{{name}}"
    just --justfile "{{justfile()}}" deploy-local "{{name}}"
    echo ":: Bootstrap complete for {{name}} ::"
