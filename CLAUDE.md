# nixos-config

Personal NixOS configuration. This repo is the *consumer* of the
[ft-home](https://github.com/track-prepped-68-corolla/ft-home) framework flake.

## Dual-flake architecture

| Repo | Role | Active branch |
|------|------|---------------|
| `ft-home` | Framework: generator, shared modules, all external inputs | `generator-fix` |
| `nixos-config` (this repo) | Consumer: hosts, homes, consumer-specific modules | `master` / feature branches |

`nixos-config/flake.nix` is intentionally minimal — it just calls
`ft-home.lib.mkFlake inputs`:

```nix
outputs = inputs @ { ft-home, ... }:
  ft-home.lib.mkFlake inputs;
```

`ft-home/lib/generator.nix` auto-discovers everything:

- **Hosts**: `hosts/<arch>/<hostname>/` → `nixosConfigurations.<hostname>`
  (or `darwinConfigurations` for `*-darwin` arches)
- **Homes**: `homes/<username>/` × each discovered host arch →
  `homeConfigurations.<username>@<arch>`

ft-home's own NixOS and home-manager modules are injected automatically into
every generated config — consumer host files must **not** import them manually.

## Directory layout

```
nixos-config/
  hosts/
    x86_64-linux/
      strix/           ← one directory per host
        default.nix
        hardware-configuration.nix
  homes/
    joe/               ← one directory per user
      default.nix
  modules/
    nixos/             ← consumer-specific NixOS modules (auto-discovered)
    home/              ← consumer-specific home-manager modules (auto-discovered)
  todo.md              ← next steps / backlog
  plan.md              ← current working plan (overwritten each session)
```

## How to add things

**New host**: create `hosts/<arch>/<hostname>/default.nix`.
Import `./hardware-configuration.nix` and `../../../modules/nixos`.
Use `ft.*` options to enable framework features. Do not import ft-home modules directly.

**New home**: create `homes/<username>/default.nix`.
Use `ft.*` options. Do not import ft-home home modules directly.

**New consumer NixOS module**: drop a `.nix` file anywhere under `modules/nixos/`.
It is auto-imported via `modules/nixos/default.nix` using
`lib.filesystem.listFilesRecursive`. No wiring needed.

**New consumer home module**: same pattern under `modules/home/`.

**New ft-home framework module**: add to `ft-home/modules/nixos/` or
`ft-home/modules/home/`, then run `nix flake update ft-home` in this repo.

## Updating ft-home

```
nix flake update ft-home
```

Do **not** run `nix flake update nixpkgs` — nixpkgs follows ft-home's pin and
has no top-level flake input node in this repo.

## Rebuilding

```bash
sudo nixos-rebuild switch --flake .#strix
home-manager switch --flake .#joe@x86_64-linux
```

## Next steps / backlog

See **`todo.md`** in this repo root.

## Rules for Claude

1. **Branch**: always develop on the branch named in the session instructions.
   Never push to `master` without explicit permission.

2. **Consumer vs framework**: consumer-specific options and modules belong in
   *this* repo. Shared framework features belong in `ft-home`. When in doubt,
   ask — don't silently put things in the wrong repo.

3. **No hardcoded paths**: never embed absolute filesystem paths (e.g.
   `/home/joe/git/nixos-config`) in Nix expressions. Use `inputs.self` or
   flake-relative paths instead.

4. **`ft.*` namespace**: all framework-provided options live under `ft.*`.
   Follow `lib.mkEnableOption` / `lib.mkOption` patterns already in use.

5. **Don't import ft-home modules manually**: host and home files must not
   `import` ft-home module paths directly. The generator injects them.

6. **`nix flake update ft-home`**: when you need a newer ft-home (new modules,
   fixes), update the ft-home input, not nixpkgs.

7. **Check todo.md first**: before proposing new work, read `todo.md` to
   understand what is already planned and what priority the user has set.

8. **plan.md is the current working plan**: at the start of any new plan,
   overwrite `plan.md` in the repo root with the new plan. At the start of a
   new session, read `plan.md` to recover context on what was in progress.
