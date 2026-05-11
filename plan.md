# Next Session Plan

## Context
The `claude/module-integration` branch in both repos is complete. All framework
modules have been reconciled between ft-home and nixos-config. Path options
(`ft.repoPath`, `ft.dotfiles.path`) are centralized. Ready to merge and move on.

---

## Step 1 — Merge branches

**ft-home:** `claude/module-integration` → `generator-fix`
**nixos-config:** `claude/module-integration` → `claude/flake-generator-consumer-X3fNL`

Nothing below can build cleanly until these are merged.

---

## Step 2 — Enable dotfiles symlinking

In `homes/joe/default.nix`, add:
```nix
ft.dotfiles.enable = true;
```

`ft.dotfiles.path` already defaults to
`${ft.repoPath}/homes/joe/dotfiles` — no other config needed.
Verify that files under `homes/joe/dotfiles/` land in `~/` after
`home-manager switch`.

---

## Step 3 — Clean up .bak files in nixos-config

Delete these dead files from `modules/nixos/`:
- `hardware/gpu.nix.bak`
- `system/cosmic.nix.bak`
- `system/rclone.nix.bak`
- `system/stylix.nix.bak`

---

## Step 4 — The Mullet

Two files:

### `ft-home/modules/nixos/apps/mullet.nix`
```nix
options.ft.mullet = {
  enable = lib.mkEnableOption "imperative package list";
  path = lib.mkOption {
    type = lib.types.str;
    default = "${config.ft.repoPath}/mullet.txt";
  };
};
config = lib.mkIf cfg.enable {
  environment.systemPackages =
    map (name: pkgs.${name})
      (lib.splitString "\n"
        (lib.strings.removeSuffix "\n"
          (builtins.readFile cfg.path)));
};
```

### `nixos-config/mullet.txt`
Flat list of package attribute names, one per line:
```
brave
vscodium
...
```

Enable in strix with `ft.mullet.enable = true`.

---

## Step 5 — sops-nix scaffolding

`ft.security.sops` option and module already exist. What's missing:

1. `ssh-to-age` derivation in `sops.nix` to auto-derive the age key from
   `/etc/ssh/ssh_host_ed25519_key` on first boot.
2. A `just bootstrap-secrets` recipe that:
   - Runs `ssh-keyscan` → `ssh-to-age` to get the host's public age key
   - Generates a Diceware passphrase
   - Creates `secrets/secrets.yaml` with `sops --encrypt`
3. Consumer adds `ft.security.sops.enable = true` in their host file
   (strix already has this set).

---

## Remaining consumer-specific files in nixos-config

These stay in nixos-config intentionally — not framework material:
- `modules/nixos/system/containers.nix` — Komodo stack
- `modules/nixos/system/kernel.nix` — CachyOS
- `modules/nixos/hardware/vm.nix` — VM defaults
- `modules/home/pixel-planet.png` — wallpaper asset
