# Komodo GitOps + secrets — strix finish-up runbook

Everything in the framework and the strix config is already in place. What's
left needs your private keys / a Komodo API key, so it can't be automated from a
sandbox. Do these steps on **strix**, top to bottom.

## What's already done

- `machines/strix/default.nix` has `ft.sops.enable = true`, plus the two Komodo
  toggles **staged as commented one-liners** with a short inline note.
- `containers/*.env` sidecars are scaffolded (this PR). `ft komodo-sync` embeds
  each one as its stack's `environment`, so the compose `${VAR}`s resolve.
  - Non-secret values are filled with defaults.
  - Two blanks in `media.env` you must fill: `VPN_SERVICE_PROVIDER`,
    `WIREGUARD_ADDRESSES` (your VPN account details — not secret).
  - Secret refs use `[[KEY]]`, resolved by Komodo from the Periphery `[secrets]`
    block you create in step B.

Secrets that must go into `komodo/periphery_secrets` (names must match the
`[[KEY]]` refs in `media.env`):

| `[[KEY]]` | what it is |
|---|---|
| `WIREGUARD_PRIVATE_KEY` | your WireGuard private key |
| `ARIA2_RPC_SECRET` | any strong random string for aria2's RPC |

---

## 0. Prerequisite — bump the framework input

This pulls in fast-track-nix **#199** (the guest-sops eval fix) and all the
Komodo work. **Without it strix won't even evaluate.**

```sh
nix flake update ft-home      # 'ft-home' is the framework input alias in flake.nix
```

## A. First deploy with the toggles still off

Leaves both Komodo toggles commented (their default state). This boots the guest
so it generates its **persistent** ed25519 host key — the age recipient the next
step needs.

```sh
ft switch
```

## B. Periphery secret injection (`peripherySecrets`)

1. Read the guest's host key and convert it to an age recipient. Find the guest
   IP from `ft.dockervm.komodo.host` (defaults to the VM's address on the
   microvm0 subnet, e.g. `http://10.0.100.2:9120` → `10.0.100.2`):

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

5. In `machines/strix/default.nix`, uncomment:

   ```nix
   ft.dockervm.komodo.peripherySecrets.enable = true;
   ```

6. Deploy. The guest now decrypts `komodo.yaml` on its own host key; Komodo can
   resolve `[[WIREGUARD_PRIVATE_KEY]]` / `[[ARIA2_RPC_SECRET]]` at deploy time.

   ```sh
   ft switch
   ```

## C. Auto-reconcile Komodo with `containers/` (`autoApply`)

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

4. In `machines/strix/default.nix`, uncomment:

   ```nix
   ft.dockervm.komodo.autoApply.enable = true;
   ```

5. Deploy. On this and every future `ft switch`, the host waits for Komodo Core,
   then creates the ResourceSync (if absent) and executes it over the API — no
   UI, no manual clicks.

   ```sh
   ft switch
   ```

## Verify

- Komodo UI (`ft.dockervm.komodo.host`, default `http://<guest-ip>:9120`) shows
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
