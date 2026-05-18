# nixos-config justfile
# Run via:  just -f scripts/.justfile <recipe>
# Or copy to repo root:  cp scripts/.justfile justfile

set quiet := true

import "./mullet.just"
import "./store.just"

default:
    just --list

alias r  := switch
alias t  := test
alias c  := check
alias cl := clean
alias s  := sync

# ─── 1. Maintenance & Checks ─────────────────────────────────────────────────

fmt:
    echo ":: Formatting ::"
    find . -name "*.nix" -exec nixfmt {} +

check: fmt
    echo ":: Scanning for leaked secrets ::"
    trufflehog git file://. --since-commit HEAD --fail 2>/dev/null

clean:
    echo ":: Cleaning Nix Store ::"
    nh clean all --keep 5

# ─── 2. Testing ──────────────────────────────────────────────────────────────

test: check
    #!/usr/bin/env bash
    echo ":: Staging & Diffs ::"
    git add .
    git diff --cached | delta --side-by-side
    echo ":: Running Test ::"
    nh os test . --ask
    echo ":: Test complete. Reboot to revert. ::"

# ─── 3. Core Workflow ────────────────────────────────────────────────────────

switch: check
    #!/usr/bin/env bash
    set -e
    echo ":: Previewing Build ::"
    git add .
    nh os test . --dry
    echo ":: Source Code Changes ::"
    git diff --cached | delta --side-by-side
    read -p "Apply and commit? [y/N]: " choice
    if [[ "$choice" =~ ^[yY]$ ]]; then
      OLD_GEN=$(readlink /nix/var/nix/profiles/system | cut -d'-' -f2)
      nh os switch .
      GEN=$(readlink /nix/var/nix/profiles/system | cut -d'-' -f2)
      NVD_DIFF=$(nvd --color never diff $(ls -d1v /nix/var/nix/profiles/system-*-link | tail -n 2))
      if ! git diff --cached --quiet; then
          echo ""
          read -p "Commit message: " msg
          git commit -m "$msg" -m "Generation: $GEN" -m "$NVD_DIFF"
      else
          echo ":: No source changes detected. Skipping git commit. ::"
      fi
      echo ":: Update Complete! Now running Generation $GEN ::"
    else
      echo "Cancelled."
      exit 1
    fi

home-switch:
    #!/usr/bin/env bash
    USER="${1:-$USER}"
    ARCH="${2:-$(uname -m)-linux}"
    home-manager switch --flake ".#${USER}@${ARCH}"

# ─── 4. Remote Syncing ───────────────────────────────────────────────────────

pull:
    echo ":: Pulling Updates ::"
    git pull --rebase --autostash
    echo ":: Incoming Source Changes ::"
    git diff HEAD@{1}..HEAD | delta --side-by-side
    echo ":: Building and Switching ::"
    nh os switch . --ask
    echo ":: System Package Changes ::"
    nvd diff $(ls -d1v /nix/var/nix/profiles/system-*-link | tail -n 2)

push:
    #!/usr/bin/env bash
    if [[ -n $(git status --porcelain) ]]; then
      echo ":: Error: Uncommitted changes. Run 'just switch' or commit manually first. ::"
      exit 1
    fi
    echo ":: Pushing to Remote ::"
    git push

sync: pull push

# ─── 5. Bootstrap ────────────────────────────────────────────────────────────

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
    if ! sops --decrypt secrets/shared/tailscale.yaml 2>/dev/null | grep -q auth-key; then
      read -rsp "Tailscale auth key (input hidden): " TS_KEY; echo
      printf 'auth-key: "%s"\n' "$TS_KEY" | sops --encrypt --input-type yaml \
        --output secrets/shared/tailscale.yaml /dev/stdin
    fi
    git add var/tailscale/ secrets/shared/tailscale.yaml
    git diff --cached --quiet || git commit -m "chore: tailscale config"
    echo ":: Tailscale configured for tailnet: $TS_TAILNET ::"

# Scaffold a new machine in machines/<name>/ and write var/local/{machineName,repoPath,system}.
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
    REPO_PATH="$(git rev-parse --show-toplevel)"
    SYSTEM="$(nix eval --impure --expr 'builtins.currentSystem' --raw)"
    mkdir -p var/local
    printf '%s' "$REPO_PATH" > var/local/repoPath
    printf '%s' "$NAME"      > var/local/machineName
    printf '%s' "$SYSTEM"    > var/local/system
    mkdir -p "${MACHINE_DIR}/var"
    cat > "${MACHINE_DIR}/default.nix" <<EOF
{ lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos
  ];

  networking.hostName = "${NAME}";
  mainuser = "joe";

  ft.repoPath = lib.removeSuffix "\n" (builtins.readFile ../../var/local/repoPath);

  ft.boot.limine.enable    = true;
  ft.security.sops.enable  = true;
  ft.desktop.cosmic.enable = true;
  ft.cli.enable            = true;

  programs.zsh.enable = true;
}
EOF
    touch "${MACHINE_DIR}/hardware-configuration.nix"
    git add "var/local/" "${MACHINE_DIR}/"
    git diff --cached --quiet || git commit -m "bootstrap: scaffold machine ${NAME}"
    echo ":: Machine ${NAME} scaffolded at ${MACHINE_DIR} ::"
    just generate-facts "${NAME}" "${IP}"

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
    echo "Add to secrets/.sops.yaml:   - &${NAME}  ${AGE_KEY}"
    echo "Then run:  sops updatekeys secrets/shared/*.yaml"

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
    just git-init                    2>/dev/null || true
    just add-machine "{{name}}" "{{ip}}"
    just secrets-init  "{{name}}"
    just deploy        "{{name}}" "{{ip}}"
    echo ":: Bootstrap complete for {{name}} ::"

# ─── 6. Emergency Recovery ───────────────────────────────────────────────────

rollback:
    #!/usr/bin/env bash
    echo ":: Rolling back ::"
    sudo nix-env --profile /nix/var/nix/profiles/system --rollback
    sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
