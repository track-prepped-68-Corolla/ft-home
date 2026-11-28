# Komodo GitOps + secrets — strix finish-up runbook

Everything in the framework and the strix config is already in place. What's
left needs your private keys, so it can't be automated from a sandbox. Do
sections A and B on **strix**, top to bottom.

## Current state

- **Done — auto-reconcile (section C):** `ft.komodoApply.strix-dvm.enable = true`
  is on in `machines/strix/default.nix`, `containers/komodo-sync.toml` is
  generated and committed, and every `ft switch` reconciles Komodo with
  `containers/` over the API.
- **Not done — Periphery secret injection (sections A + B):** none of the
  secrets toggles are enabled yet (the staged notes are in
  `machines/strix/default.nix`).
- `containers/*.env` sidecars are scaffolded. `ft komodo-sync` embeds
  each one as its stack's `environment`, so the compose `${VAR}`s resolve.
  - Non-secret values are filled with defaults.
  - Two blanks in `media.env` you must fill: `VPN_SERVICE_PROVIDER`,
    `WIREGUARD_ADDRESSES` (your VPN account details — not secret).
  - Secret refs use `[[KEY]]`, resolved by Komodo from the Periphery `[secrets]`
    block you create in section B.

The microVM is a standalone guest (`vms/strix-dvm/`) that strix runs by
reference through `ft.microvms.instances.strix-dvm`. Guest-side toggles go in
the `vms/` file; host-side toggles go in the machine file.

Secrets that must go into `komodo/periphery_secrets` (names must match the
`[[KEY]]` refs in `media.env`, `discoverability.env`, `observability.env` and `ai.env`):

| `[[KEY]]` | what it is |
|---|---|
| `WIREGUARD_PRIVATE_KEY` | your WireGuard private key |
| `ARIA2_RPC_SECRET` | any strong random string for aria2's RPC |
| `HOMARR_SECRET_ENCRYPTION_KEY` | 64 hex chars: `openssl rand -hex 32` (Homarr won't start without it) |
| `GRAFANA_ADMIN_PASSWORD` | Grafana `admin` password (the stack refuses to start without it) |
| `SEARXNG_SECRET` | any strong random string (SearXNG `server.secret_key`) |
| `ANYTHINGLLM_JWT_SECRET` | any strong random string (AnythingLLM session signing) |

---

## A. Enable the guest's sops plumbing

```nix
# vms/strix-dvm/default.nix — guest sops plumbing
ft.vmSecrets.enable = true;

# machines/strix/default.nix — share var/secrets into the guest (read-only)
ft.microvms.instances.strix-dvm.shareSecrets = true;
```

Both halves go together: `ft.vmSecrets` mounts the share that `shareSecrets`
provisions on the host. No secrets are declared yet, so nothing is decrypted.
Deploy once. The guest boots and generates its **persistent** ed25519 host key
(on its own `sshkeys` volume) — the age recipient the next step needs.

```sh
ft switch
```

## B. Periphery secret injection (`ft.komodo.secrets.periphery`)

1. Read the guest's host key and convert it to an age recipient. Find the guest
   IP from the instance's `vmAddressSuffix` on the microvm0 subnet (strix-dvm
   has suffix `2`, so with the default `ft.microvms.hostAddress` it is
   `10.0.100.2`):

   ```sh
   ssh-keyscan <guest-ip> 2>/dev/null | ssh-to-age
   ```

2. Add that recipient to `var/secrets/.sops.yaml` as a **separate creation_rule
   for `komodo.yaml`** (so only the guest can read it — not your host secrets).
   sops uses the **first** rule whose `path_regex` matches, so this rule must
   go **above** the existing catch-all `.*\.yaml$` rule — below it, the
   catch-all would win and `komodo.yaml` would be encrypted to the host keys
   instead of the guest:

   ```yaml
   # var/secrets/.sops.yaml
   keys:
     - &komodo_guest age1...    # the recipient from step 1
   creation_rules:
     - path_regex: komodo\.yaml$        # FIRST — must precede the catch-all
       key_groups:
         - age: [*komodo_guest]
     - path_regex: .*\.yaml$            # existing catch-all, unchanged
       key_groups:
         - age: [*strix, *lyra, *yubikey]
   ```

3. Create `var/secrets/komodo.yaml` with the periphery `[secrets]`:

   ```sh
   sops var/secrets/komodo.yaml
   ```
   ```yaml
   komodo:
       periphery_secrets: |
           [secrets]
           WIREGUARD_PRIVATE_KEY        = "your-real-wg-private-key"
           ARIA2_RPC_SECRET             = "any-strong-random-string"
           HOMARR_SECRET_ENCRYPTION_KEY = "output-of-openssl-rand-hex-32"
           GRAFANA_ADMIN_PASSWORD       = "your-grafana-admin-password"
           SEARXNG_SECRET               = "any-strong-random-string"
           ANYTHINGLLM_JWT_SECRET       = "any-strong-random-string"
   tailscale:
       # Reusable auth key (Tailscale admin console → Settings → Keys) so the
       # strix-dvm node auto-joins the tailnet — see vms/strix-dvm.
       authkey: tskey-auth-...
   ```

4. Fill the two non-secret blanks in `containers/media.env`
   (`VPN_SERVICE_PROVIDER`, `WIREGUARD_ADDRESSES`) and commit the `.env` files.

5. Turn the Periphery tier on in the guest:

   ```nix
   # vms/strix-dvm/default.nix — inside the existing ft.komodo block
   ft.komodo.secrets.periphery.enable = true;
   ```

6. Deploy. The guest now decrypts `komodo.yaml` on its own host key; Komodo can
   resolve every `[[KEY]]` above at deploy time.

   ```sh
   ft switch
   ```

## Grow the Docker volume to 60 GiB (one-time)

`vms/strix-dvm` now asks for a 60 GiB `/var/lib/docker`, but microvm only
creates the image when it is missing — an existing 20 GiB `docker.img` stays
20 GiB. Grow it once on **strix** with the VM stopped:

```sh
sudo systemctl stop microvm@strix-dvm
sudo truncate -s 60G /var/lib/microvm/strix-dvm/docker.img
sudo e2fsck -f /var/lib/microvm/strix-dvm/docker.img
sudo resize2fs /var/lib/microvm/strix-dvm/docker.img
sudo systemctl start microvm@strix-dvm
```

(Or delete `docker.img` and let it be recreated at 60 GiB — this throws away
every image and named volume, which then re-pull / start empty.)

## Reaching the UIs

strix-dvm joins the tailnet as `strix-dvm`. Until Periphery secrets (section B)
are on, it can't read its auth key, so join it once by hand:

```sh
ssh root@10.0.100.2 tailscale up
```

Its state lives on its own `tailscale.img` volume, so it stays the same node
across restarts. Caddy (`discoverability` stack) serves everything as a path on
that one host — `containers/config/caddy/Caddyfile` is the full map:

| URL | app | one-time setting in the app |
|---|---|---|
| `http://strix-dvm/` | Homarr | — |
| `/sonarr` `/radarr` `/prowlarr` | *arr | — (URL base set by env) |
| `/bazarr` | Bazarr | Settings → General → URL Base = `/bazarr` |
| `/jellyfin` | Jellyfin | Dashboard → Networking → Base URL = `/jellyfin` |
| `/qbittorrent/` `/ariang/` | downloads | AriaNg RPC: host `strix-dvm`, port 80, path `/jsonrpc` |
| `/grafana` | Grafana | — |
| `/searxng/` | SearXNG | — |
| `http://strix-dvm:8123` | Home Assistant | no sub-path support → direct |
| `http://strix-dvm:9120` | Komodo | direct |
| `http://strix-dvm:3001` | AnythingLLM | no sub-path support → direct |

zigbee2mqtt is disabled (commented out in `homeautomation.yaml`) until a Zigbee
dongle is passed through into the VM.

## C. Auto-reconcile Komodo with `containers/` (`ft.komodoApply`) — done

Kept for reference, or for setting up another host such as mimir.

1. In Komodo → **Settings → API Keys**, create a key (note the key + secret).

2. Add it to your **host** secrets (`var/secrets/secrets.yaml`, host recipient):

   ```sh
   sops var/secrets/secrets.yaml
   ```
   ```yaml
   komodo:
       api_env: |
           KOMODO_API_KEY=K-xxxxxxxx
           KOMODO_API_SECRET=S-xxxxxxxx
   ```

3. Generate the sync manifest (run on **strix** so the git remote is the real
   GitHub URL), then commit + push it:

   ```sh
   ft komodo-sync                 # writes containers/komodo-sync.toml
                                  # Args are positional (just): `server account`.
                                  # server must match ft.komodo.serverName
                                  # ("Local"). `ft komodo-sync account=` sets
                                  # the SERVER to "account=" — use
                                  # `ft komodo-sync Local ""` for no git account.
   git add containers/komodo-sync.toml containers/*.env
   git commit -m "komodo: generate stack sync manifest" && git push
   ```

4. In `machines/strix/default.nix`, enable:

   ```nix
   ft.komodoApply.strix-dvm.enable = true;
   ```

5. Deploy. On this and every future `ft switch`, `komodo-apply-strix-dvm.service`
   on the host waits for Komodo Core,
   then creates the ResourceSync (if absent) and executes it over the API — no
   UI, no manual clicks.

   ```sh
   ft switch
   ```

## Verify

- Komodo UI (`http://<guest-ip>:9120`, e.g. `http://10.0.100.2:9120`) shows
  the stacks (`ai`, `discoverability`, `homeautomation`, `media`, `observability`)
  as a synced ResourceSync.
- If a stack updated on a push but didn't redeploy, force it (Komodo #1120):

  ```sh
  ft komodo-deploy media      # one stack
  ft komodo-deploy            # all stacks
  ```

## Notes

- `managed = false` in the generated sync means it never deletes resources it
  doesn't define. Flip it to `true` once you trust it as the single source of
  truth (then removing a compose file also removes its stack).
- Re-run `ft komodo-sync` and commit whenever you add/remove a `containers/*.yaml`
  or change a `.env`.
- Framework reference: `fast-track-nix/NOTES.md` → "Komodo GitOps" and
  "Injecting secrets into the Stacks Komodo deploys".
