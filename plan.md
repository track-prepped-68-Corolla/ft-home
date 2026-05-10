# Current Plan

## Task: Module Integration

Reconcile ft-home `.bak` modules with consumer duplicates. Move framework
modules to ft-home, delete consumer copies.

## Branches

- ft-home: `claude/module-integration` (based on `generator-fix`)
- nixos-config: `claude/module-integration` (based on `claude/flake-generator-consumer-X3fNL`)

## Status

In progress.

### ft-home `claude/module-integration`
- [x] `modules/nixos/system/core.nix` — comprehensive baseline, flakeDir default fixed to `""`
- [x] `modules/nixos/system/user.nix` — u2fMappings option, conditional groups
- [x] `modules/nixos/system/limine.nix`
- [x] `modules/nixos/system/sops.nix`
- [x] `modules/nixos/system/just.nix`
- [x] `modules/nixos/desktops/cosmic.nix`
- [x] `modules/nixos/profiles/gaming.nix` — user default uses config.mainuser
- [x] `modules/home/home-core.nix` — without openldap overlay
- [ ] Delete .bak files

### nixos-config `claude/module-integration`
- [x] `hosts/x86_64-linux/strix/default.nix` — added ft.flakeDir
- [ ] Delete consumer duplicate modules

## Verification

```bash
sudo nixos-rebuild switch --flake .#strix
home-manager switch --flake .#joe@x86_64-linux
```

## What was done previously

- Fixed home-manager build errors
- Added CachyOS kernel module (nixos-config)
- Implemented idiomatic module exposure in ft-home (generator-fix branch)
- Created CLAUDE.md and plan.md
