#!/usr/bin/env bash
# strix-dvm runbook helper — the hands-on steps of containers/komodo-gitops-setup.md.
#
# Run on strix from the ft-home checkout. One step per invocation, in order:
#
#   containers/strix-dvm-runbook.sh resize      # grow docker.img to 60 GiB (stops/starts the VM)
#   containers/strix-dvm-runbook.sh tailscale   # one-time manual tailnet join of the guest
#   containers/strix-dvm-runbook.sh recipient   # guest host key -> age recipient -> .sops.yaml
#   containers/strix-dvm-runbook.sh secrets     # write + encrypt var/secrets/komodo.yaml
#   containers/strix-dvm-runbook.sh verify      # check secrets keys, Komodo and Caddy
#
# Before `recipient`: ft.vmSecrets.enable (guest) + shareSecrets (host), `ft switch`.
# After `secrets`:    fill media.env VPN blanks, ft.komodo.secrets.periphery.enable,
#                     commit, `ft switch`, then `verify`.
set -euo pipefail

VM=strix-dvm
GUEST=10.0.100.2
IMG_DIR=/var/lib/microvm/$VM
REPO=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "run inside the ft-home checkout" >&2; exit 1; }
SECRETS_DIR=$REPO/var/secrets
SOPS_CFG=$SECRETS_DIR/.sops.yaml

say() { printf '\n:: %s\n' "$*"; }
die() { printf ':: error: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null || die "missing '$1' (try: nix shell nixpkgs#$2)"; }

cmd_resize() {
  local img=$IMG_DIR/docker.img
  sudo test -f "$img" || die "$img not found — has the VM booted once?"
  local size
  size=$(sudo stat -c %s "$img")
  if (( size >= 60 * 1024 ** 3 )); then say "docker.img is already >= 60 GiB"; return; fi
  say "Stopping microvm@$VM and growing $img to 60 GiB"
  sudo systemctl stop "microvm@$VM"
  sudo truncate -s 60G "$img"
  sudo e2fsck -fy "$img" || [ $? -le 1 ]   # exit 1 = errors corrected, fine
  sudo resize2fs "$img"
  sudo systemctl start "microvm@$VM"
  say "Done. Guest restarting."
}

cmd_tailscale() {
  say "Joining $VM to the tailnet (follow the login URL it prints)"
  ssh "root@$GUEST" tailscale up
  ssh "root@$GUEST" tailscale status | head -5
}

cmd_recipient() {
  need ssh-to-age ssh-to-age
  local rcpt
  rcpt=$(ssh-keyscan -t ed25519 "$GUEST" 2>/dev/null | ssh-to-age) \
    || die "couldn't read the guest host key — is ft.vmSecrets on and the VM up?"
  [[ $rcpt == age1* ]] || die "unexpected recipient: $rcpt"
  say "Guest recipient: $rcpt"

  if grep -q '&komodo_guest' "$SOPS_CFG"; then
    say ".sops.yaml already has a komodo_guest key — check it matches, not touching it"
    return
  fi
  cp "$SOPS_CFG" "$SOPS_CFG.bak"
  # Key anchor after `keys:`; komodo.yaml rule FIRST under creation_rules,
  # because sops uses the first matching path_regex. Encrypted to the guest
  # (so it can decrypt) and strix's host key (so you can still edit it with
  # `sudo SOPS_AGE_SSH_PRIVATE_KEY_FILE=/etc/ssh/ssh_host_ed25519_key sops ...`;
  # strix root can read the guest's disk anyway, so this costs no isolation).
  awk -v r="$rcpt" '
    /^keys:/           { print; print "  - &komodo_guest " r "   # strix-dvm guest host key"; next }
    /^creation_rules:/ { print
                         print "  - path_regex: komodo\\.yaml$"
                         print "    key_groups:"
                         print "      - age: [*komodo_guest, *strix]"
                         next }
    { print }' "$SOPS_CFG.bak" > "$SOPS_CFG"
  say "Updated $SOPS_CFG (backup: .sops.yaml.bak):"
  git -C "$REPO" diff -- "$SOPS_CFG"
}

cmd_secrets() {
  need sops sops
  need openssl openssl
  local out=$SECRETS_DIR/komodo.yaml
  [ -e "$out" ] && die "$out exists — edit it with: sops $out"
  grep -q '&komodo_guest' "$SOPS_CFG" || die "run '$0 recipient' first"

  local wg ts
  read -rsp "WireGuard private key: " wg; echo
  read -rsp "Tailscale reusable auth key (tskey-auth-...): " ts; echo
  [ -n "$wg" ] && [ -n "$ts" ] || die "both keys are required"

  local grafana
  grafana=$(openssl rand -base64 18 | tr -d '/+=')
  local plain
  plain=$(mktemp -p /dev/shm komodo.XXXXXX)
  trap 'shred -u "$plain" 2>/dev/null || rm -f "$plain"' EXIT
  chmod 600 "$plain"
  cat > "$plain" <<EOF
komodo:
    periphery_secrets: |
        [secrets]
        WIREGUARD_PRIVATE_KEY        = "$wg"
        ARIA2_RPC_SECRET             = "$(openssl rand -hex 24)"
        HOMARR_SECRET_ENCRYPTION_KEY = "$(openssl rand -hex 32)"
        GRAFANA_ADMIN_PASSWORD       = "$grafana"
        SEARXNG_SECRET               = "$(openssl rand -hex 32)"
        ANYTHINGLLM_JWT_SECRET       = "$(openssl rand -hex 32)"
tailscale:
    authkey: "$ts"
EOF
  # sops picks its config from the cwd upward, and the rule by filename.
  (cd "$SECRETS_DIR" && sops --encrypt --filename-override komodo.yaml "$plain" > komodo.yaml)
  say "Wrote $out (encrypted to the guest + strix host key)."
  say "Grafana login: admin / $grafana   (save it in KeePassXC)"
}

cmd_verify() {
  say "komodo.yaml top-level keys:"
  grep -oE '^[a-z_]+:|^    [a-z_]+:' "$SECRETS_DIR/komodo.yaml" || echo "  (missing)"
  say "Guest sees the secret?"
  ssh "root@$GUEST" 'ls -l /run/secrets/komodo/periphery_secrets /run/secrets/tailscale/authkey' || true
  say "Komodo Core:"
  curl -fsS -o /dev/null -w '  HTTP %{http_code}\n' "http://$GUEST:9120" || echo "  unreachable"
  say "Caddy via tailnet (http://$VM/):"
  curl -fsS -o /dev/null -w '  HTTP %{http_code}\n' "http://$VM/" || echo "  unreachable"
  say "Containers in the guest:"
  ssh "root@$GUEST" "docker ps --format '  {{.Names}}\t{{.Status}}'" || true
}

case "${1:-}" in
  resize | tailscale | recipient | secrets | verify) "cmd_$1" ;;
  *) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
