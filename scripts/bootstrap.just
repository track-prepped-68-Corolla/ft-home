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
    git add var/git/ var/local/
    git diff --cached --quiet || git commit -m "chore: store git config and local system in var"
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
    STATE_VERSION="$(nix eval --impure --expr '
      let
        lock = builtins.fromJSON (builtins.readFile ./flake.lock);
        npSrc = builtins.fetchTree lock.nodes.nixpkgs.locked;
      in (import "${npSrc}/lib").trivial.release
    ' --raw 2>/dev/null | sed 's/pre.*//')"
    STATE_VERSION="${STATE_VERSION:-25.05}"
    mkdir -p var/local
    printf '%s' "$NAME"   > var/local/machineName
    printf '%s' "$SYSTEM" > var/local/system
    mkdir -p "${MACHINE_DIR}/modules"
    mkdir -p "${MACHINE_DIR}/var"
    cat > "${MACHINE_DIR}/default.nix" <<EOF
{ ... }:
{
  imports = [
    ./modules
    ../../modules/nixos
  ];

  networking.hostName = "${NAME}";
  mainuser = "joe";
  superUsers = [ "joe" ];
  users.users.joe.initialPassword = "nixos";
  users.mutableUsers = true;

  ft.system.core.stateVersion = "${STATE_VERSION}";
  ft.boot.limine.enable    = true;
  ft.desktop.cosmic.enable = true;
  ft.cli.enable            = true;

  ft.mullet = {
    enable     = true;
    sourcePath = ../../users/joe/var/mullet.txt;
  };

  ft.security.sops = {
    enable = true;
    useTPM = true;
  };

  ft.hardware.facter = {
    enable     = true;
    reportPath = ./var/facter.json;
  };

  nixpkgs.hostPlatform = "${SYSTEM}";
}
EOF
    cat > "${MACHINE_DIR}/modules/default.nix" <<'EOF'
{ lib, ... }:
let
  allFiles = lib.filesystem.listFilesRecursive ./.;
  validModules = builtins.filter (
    path: lib.hasSuffix ".nix" (builtins.toString path) && path != ./default.nix
  ) allFiles;
in
{
  imports = validModules;
}
EOF
    git add "var/local/" "${MACHINE_DIR}/"
    git diff --cached --quiet || git commit -m "bootstrap: scaffold machine ${NAME}"
    echo ":: Machine ${NAME} scaffolded at ${MACHINE_DIR} ::"
    just --justfile "{{justfile()}}" generate-facts "${NAME}" "${IP}"

# Generate SSH host key + age pubkey, print instructions for .sops.yaml.
secrets-init name:
    #!/usr/bin/env bash
    set -e
    NAME="{{name}}"
    TMPDIR="/tmp/bootstrap-${NAME}"
    mkdir -p "$TMPDIR"
    ssh-keygen -t ed25519 -N "" -f "${TMPDIR}/ssh_host_ed25519_key" -C "root@${NAME}"
    AGE_KEY=$(ssh-to-age < "${TMPDIR}/ssh_host_ed25519_key.pub")
    echo ":: Age pubkey for ${NAME}: ${AGE_KEY} ::"
    echo ""
    echo "Add to var/secrets/.sops.yaml:   - &${NAME}  ${AGE_KEY}"
    echo "Then run:  sops updatekeys var/secrets/shared/*.yaml"

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

# Install NixOS on target via nixos-anywhere.
deploy name ip:
    #!/usr/bin/env bash
    set -e
    NAME="{{name}}"
    IP="{{ip}}"
    TMPDIR="/tmp/bootstrap-${NAME}"
    EXTRA_FILES=""
    if [ -f "${TMPDIR}/ssh_host_ed25519_key" ]; then
      mkdir -p "${TMPDIR}/etc/ssh"
      cp "${TMPDIR}/ssh_host_ed25519_key"     "${TMPDIR}/etc/ssh/"
      cp "${TMPDIR}/ssh_host_ed25519_key.pub" "${TMPDIR}/etc/ssh/"
      EXTRA_FILES="--extra-files ${TMPDIR}"
    fi
    nixos-anywhere --flake ".#${NAME}" $EXTRA_FILES "root@${IP}"

# Full bootstrap: git-init → add-machine (includes generate-facts) → secrets-init → deploy.
bootstrap name ip:
    #!/usr/bin/env bash
    set -e
    just --justfile "{{justfile()}}" git-init 2>/dev/null || true
    just --justfile "{{justfile()}}" add-machine "{{name}}" "{{ip}}"
    just --justfile "{{justfile()}}" secrets-init "{{name}}"
    just --justfile "{{justfile()}}" deploy "{{name}}" "{{ip}}"
    echo ":: Bootstrap complete for {{name}} ::"
