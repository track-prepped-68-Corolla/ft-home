# ft-home — Developer Reference

## Repository naming

This repo is named **`ft-home`** on GitHub and is the personal consumer of the framework. The framework itself lives in the separate **`fast-track-nix`** GitHub repo, but is aliased as `ft-home` in this repo's flake inputs for historical reasons. Outside of explicit "this repo" references, "ft-home" in this file means the framework input (`fast-track-nix`), not the consumer repo you are reading this in. Keep this collision in mind when reading across repos.

---

## What this is

ft-home (this repo) is the personal consumer of the framework. It serves two purposes:

1. Daily-driver configuration for real machines.
2. Dogfood testbed for ft-home features in development.

`flake.nix` delegates entirely to `ft-home.lib.mkFlake inputs` — no extra outputs, no VM test packages. The VM smoke test suite lives in the separate `ft-testing` repo:
`https://github.com/track-prepped-68-Corolla/ft-testing`

---

## Structure

```
flake.nix                           # pure delegation — ft-home.lib.mkFlake inputs
flake.lock                          # intentional; tracks ft-home and all transitive inputs
machines/
  <name>/
    default.nix                     # ft.* option settings for this machine
    modules/
      default.nix                   # imports machine-local modules
      disko.nix                     # declarative disk layout for this machine
    var/
      facter.json                   # hardware report — source of truth for system arch
users/
  admin/                            # default admin user
  guest/                            # default guest user
  <username>/
    default.nix
modules/
  nixos/                            # consumer-local NixOS modules (staging area for framework candidates)
  home/                             # consumer-local HM modules
var/
  local/                            # local machine state (system string written by bootstrap)
  secrets/
    .sops.yaml                      # sops key configuration
```

There is no `scripts/` directory in this repo — the `ft` CLI just-recipes
(`ft.just`, `sys.just`, `bootstrap.just`, `mullet.just`, `store.just`,
`drives.just`, `failover.just`) are bundled inside `fast-track-nix` and
invoked via the `ft.cli` wrapper, with `ft.repoPath` passed as the
`--working-directory` target.

---

## Adding machines and users

- **New machine:** create `machines/<name>/default.nix`. The ft-home generator picks it up automatically.
- **System architecture:** determined from `machines/<name>/var/facter.json` (`facter.system`). Run `nixos-facter` on the target and commit the output there. The generator falls back to `x86_64-linux` if the file is absent.
- **New user:** create `users/<username>/default.nix`. Cross-producted with every machine system automatically.
- **Machine-local modules:** place them under `machines/<name>/modules/` and import via that directory's `default.nix`. Use for machine-specific config (e.g., disk layout via disko) that is not generic enough for ft-home.

Machine files contain `ft.*` option assignments and machine-local module imports only. No reusable abstractions.

---

## Hard rules

### Never update nixpkgs independently

nixpkgs has no standalone input node — it follows ft-home's pin via `follows`. Do not run `nix flake update nixpkgs`. To update nixpkgs, run `nix flake update ft-home`.

### Logic belongs in ft-home

This repo is configuration values, not code. If a change requires a reusable function, a module with options, or anything another consumer could use, that work goes into the framework first. `modules/` here is a staging area for consumer-specific overrides pending upstreaming — not a permanent home for framework logic.

### Dependency direction is one-way

This repo depends on the framework (ft-home). The framework must never reference or depend on this repo.

---

## Provisioning workflow

New machines are provisioned with nixos-anywhere + disko + nixos-facter:

1. Boot the target into a NixOS live environment.
2. Run `nixos-facter` to generate `facter.json`; commit it to `machines/<name>/var/`.
3. Define the disk layout in `machines/<name>/modules/disko.nix`.
4. Run nixos-anywhere pointing at `ft-home#<name>`. Disko handles partitioning declaratively as part of the install.

---

## Known issues / pending fixes

- **Broken wallpaper default path in `ft.theme` / `stylix.nix`:** The framework module (`fast-track-nix/modules/home/stylix.nix`) defaults the wallpaper to `../../homes/guest/wallpapers/default.png`. The actual directory is `users/`, not `homes/` — this path resolves to a nonexistent location. Tracked in `Todo.md`. Until fixed upstream, always set `ft.theme.wallpaper` explicitly in your user config.

---

## Secrets

Managed by sops-nix. Key configuration lives in `var/secrets/.sops.yaml`. Age recipients are SSH host keys. `ft.sops.useTPM` and `ft.sops.useYubikey` provide hardware-token alternatives. Never commit unencrypted secrets.

---

## Quality checks

All four must pass before every commit.

```bash
treefmt          # nixfmt (format) + deadnix --edit (remove dead bindings)
statix check .   # Nix anti-pattern linter
trufflehog git . # credential and secret scanner
nix flake check  # validates all outputs build and evaluate cleanly
```

---

## VM Smoke Tests

VM smoke tests for all framework modules now live in the `ft-testing` repo:
`https://github.com/track-prepped-68-Corolla/ft-testing`

The `VM Smoke Tests` `workflow_dispatch` workflow in ft-testing runs the full suite against the framework's `testing` branch.

---

## Branch workflow

`feature` → `testing` → `main`

All pull requests target `testing`, not `main`. Changes reach `main` only after passing on `testing`. Never open a PR directly against `main`.

---

## What Claude must never do

- Run `nix flake update nixpkgs` or `nix flake update` without explicit instruction.
- Write reusable logic or module definitions here that belong in ft-home.
- Use `lib.mkForce` except for an explicitly documented security or safety invariant.
- Refactor existing machine or user files unless the task explicitly requires it.
- Expand scope beyond what was asked.
- Commit unencrypted secrets or credentials.
- Open a pull request targeting `main` — all PRs target `testing`.
- Add VM tests here — they belong in ft-testing.
