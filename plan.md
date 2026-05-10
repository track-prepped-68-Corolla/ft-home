# Current Plan

## Task: Module Integration — COMPLETE

Reconciled ft-home `.bak` modules with consumer duplicates. Framework modules
now live in ft-home and are injected automatically via the generator.

## Branches

- ft-home: `claude/module-integration` (based on `generator-fix`)
- nixos-config: `claude/module-integration` (based on `claude/flake-generator-consumer-X3fNL`)

## What was done

### ft-home `claude/module-integration`
- [x] `modules/nixos/system/core.nix` — comprehensive baseline; flakeDir default = `""`
- [x] `modules/nixos/system/user.nix` — u2fMappings option, conditional commonGroups
- [x] `modules/nixos/system/limine.nix`
- [x] `modules/nixos/system/sops.nix`
- [x] `modules/nixos/system/just.nix` — ft CLI wrapper using scripts/ft.just
- [x] `modules/nixos/desktops/cosmic.nix`
- [x] `modules/nixos/profiles/gaming.nix` — user default uses config.mainuser
- [x] `modules/home/home-core.nix` — without openldap overlay
- [x] All `.bak` files deleted

### nixos-config `claude/module-integration`
- [x] `hosts/x86_64-linux/strix/default.nix` — added ft.flakeDir
- [x] Deleted consumer duplicates: core, user, limine, sops, just, cosmic, home-core

## Verification

```bash
# Update ft-home input to pick up module-integration branch
# (temporarily point flake.nix at claude/module-integration, or merge into generator-fix first)
nix flake update ft-home
sudo nixos-rebuild switch --flake .#strix
home-manager switch --flake .#joe@x86_64-linux
```

## Next up (from todo.md)

- Merge `ft-home/claude/module-integration` → `generator-fix`
- Merge `nixos-config/claude/module-integration` → `claude/flake-generator-consumer-X3fNL`
- Export `packages.default` (ft CLI wrapper) from ft-home flake
- Re-enable sops-nix and set up ssh-to-age pipeline
- Set up facter modules
