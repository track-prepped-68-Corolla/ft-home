# Current Plan

## Task

Create `CLAUDE.md` in nixos-config documenting the project, dual-flake
architecture, directory conventions, and rules for Claude.

## Status

Complete — `CLAUDE.md` committed to `claude/flake-generator-consumer-X3fNL`.

## What was done this session

- Fixed home-manager build errors (nodePackages removed, unfree packages,
  wallpaper path)
- Added CachyOS kernel module to `nixos-config/modules/nixos/system/kernel.nix`
- Implemented idiomatic module exposure in ft-home (`generator-fix` branch):
  ft-home exports `nixosModules.default` / `homeManagerModules.default`;
  generator receives them as `ftNixos` / `ftHome` args captured before inputs merge
- Renamed ft-home module `.nix` files to `.bak` to prevent option collision
  until consumer modules are reconciled
- Updated and committed `todo.md`
- Created `CLAUDE.md` and this `plan.md`

## Next up (from todo.md)

- Reconcile ft-home `.bak` modules with consumer duplicates
- Fix `ft.flakeDir` hardcoded path in `core.nix.bak`
- Export `packages.default` (ft CLI wrapper) from ft-home flake
- Re-enable sops-nix and set up ssh-to-age pipeline
