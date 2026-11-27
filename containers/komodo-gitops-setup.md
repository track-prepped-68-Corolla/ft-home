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
`[[KEY]]` refs in `media.env`):

| `[[KEY]]` | what it is |
|---|---|
| `WIREGUARD_PRIVATE_KEY` | your WireGuard private key |
| `ARIA2_RPC_SECRET` | any strong random string for aria2's RPC |

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
   for `komodo.yaml`** (so only the guest can read it — not your host secrets):

   ```yaml
   # var/secrets/.sops.yaml
   keys:
     - &komodo_guest age1...    # the recipient from step 1
   creation_rules:
     - path_regex: komodo\.yaml$
       key_groups:
         - age: [*komodo_guest]
     # (your existing rule for the other *.yaml files stays as-is)
   ```

3. Create `var/secrets/komodo.yaml` with the periphery `[secrets]`:

   ```sh
   sops var/secrets/komodo.yaml
   ```
   ```yaml
   komodo:
       periphery_secrets: |
           [secrets]
           WIREGUARD_PRIVATE_KEY = "your-real-wg-private-key"
           ARIA2_RPC_SECRET      = "any-strong-random-string"
   ```

4. Fill the two non-secret blanks in `containers/media.env`
   (`VPN_SERVICE_PROVIDER`, `WIREGUARD_ADDRESSES`) and commit the `.env` files.

5. Turn the Periphery tier on in the guest:

   ```nix
   # vms/strix-dvm/default.nix — inside the existing ft.komodo block
   ft.komodo.secrets.periphery.enable = true;
   ```

6. Deploy. The guest now decrypts `komodo.yaml` on its own host key; Komodo can
   resolve `[[WIREGUARD_PRIVATE_KEY]]` / `[[ARIA2_RPC_SECRET]]` at deploy time.

   ```sh
   ft switch
   ```

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
  the four stacks (`media`, `homeAutomation`, `discoverability`, `observability`)
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
