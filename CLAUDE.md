# nixos-config — Developer Reference

## Repository naming

This repo is named **`ft-home`** on GitHub but is called **`nixos-config`** throughout this file — that name reflects what any private consumer repo using this framework would typically be called. The framework that this repo consumes is in the separate **`fast-track-nix`** GitHub repo, aliased as `ft-home` in flake inputs. The naming is an inversion: the *framework* is called `ft-home` in inputs; the *consumer* is the `ft-home` repo. Keep this in mind when reading across repos.

---

## What this is

nixos-config is the personal consumer of the ft-home framework. It serves three purposes:

1. Daily-driver configuration for real machines.
2. Dogfood testbed for ft-home features in development.
3. Reference implementation until a dedicated template consumer repo is created.

The core of `flake.nix` delegates to `ft-home.lib.mkFlake inputs`. The only consumer-level addition is `packages.x86_64-linux = import ./tests/vm { … }`, which merges VM smoke test packages in via `nixpkgs.lib.recursiveUpdate` without affecting any other outputs.

---

## Structure

```
flake.nix                           # delegation — ft-home.lib.mkFlake inputs + test package merge
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
                                    # contains: apps/ (mullet), hardware/ (facter, gpu, disk, nfs, vm),
                                    #           services/ (local-ai)
  home/                             # consumer-local HM modules (currently sparse — single default.nix)
tests/
  vm/
    lib.nix                         # shared baseConfig and consumerBaseConfig
    default.nix                     # merges all test files into packages.x86_64-linux.vm-*
    fixtures/                       # test data (mullet.txt, facter.json)
    <feature>.nix                   # one file per module under test
var/
  local/                            # local machine state (system string written by bootstrap)
  secrets/
    .sops.yaml                      # sops key configuration
scripts/
  ft.just                           # entry point: imports all sub-modules
  sys.just                          # daily driver: switch, pull, rollback, clean, fmt, check
  bootstrap.just                    # provisioning: git-init, add-machine, secrets-init, deploy
  mullet.just                       # package escape hatch: add/remove/list packages
  store.just                        # dotfile store management (experimental)
  drives.just                       # drive/disk utilities (mount, format, SMART checks)
```

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

nixos-config is configuration values, not code. If a change requires a reusable function, a module with options, or anything another consumer could use, that work goes into ft-home first. `modules/` here is a staging area for consumer-specific overrides pending upstreaming — not a permanent home for framework logic.

### Dependency direction is one-way

nixos-config depends on ft-home. ft-home must never reference or depend on nixos-config.

---

## Provisioning workflow

New machines are provisioned with nixos-anywhere + disko + nixos-facter:

1. Boot the target into a NixOS live environment.
2. Run `nixos-facter` to generate `facter.json`; commit it to `machines/<name>/var/`.
3. Define the disk layout in `machines/<name>/modules/disko.nix`.
4. Enable `ft.hardware.facter` (consumer-local module in `modules/nixos/hardware/facter.nix`) and the GPU module if needed.
5. Run nixos-anywhere pointing at `nixos-config#<name>`. Disko handles partitioning declaratively as part of the install.

Note: `ft.hardware.facter` and `ft.hardware.gpu` are currently consumer-local modules (not yet in the framework). They live in `modules/nixos/hardware/` here and must be imported explicitly in your machine config until they are upstreamed.

---

## Known issues / pending fixes

- **Broken wallpaper default path in `ft.theme` / `stylix.nix`:** The framework module (`fast-track-nix/modules/home/stylix.nix`) defaults the wallpaper to `../../homes/guest/wallpapers/default.png`. The actual directory is `users/`, not `homes/` — this path resolves to a nonexistent location. Tracked in `Todo.md`. Until fixed upstream, always set `ft.theme.wallpaper` explicitly in your user config.
- **`ft.hardware.facter` does not import `nixos-facter.nixosModules.facter`:** The consumer module sets `config.facter.reportPath` (an option from `inputs.nixos-facter`) but relies on the generator to inject the upstream module. VM tests must import it explicitly. The module itself should be fixed to add the import.

---

## Secrets

Managed by sops-nix. Key configuration lives in `var/secrets/.sops.yaml`. Age recipients are SSH host keys. `ft.security.sops.useTPM` and `ft.security.sops.useYubikey` provide hardware-token alternatives. Never commit unencrypted secrets.

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

VM smoke tests are the integration tier for all ft-home and framework modules.
They live in `tests/vm/` and are exposed as `packages.x86_64-linux.vm-*` from
`flake.nix` (via `recursiveUpdate`, so they stay out of `nix flake check` and
do not affect the existing CI pipeline).

**Run a test locally:**
```bash
nix build -L --no-link \
  --option system-features "nixos-test kvm benchmark big-parallel" \
  .#vm-core-boot
```

**Trigger all tests:** Runs automatically on push/PR to `testing`. Also available via `workflow_dispatch`.

### File layout

```
tests/vm/
  lib.nix              # baseConfig (framework only) + consumerBaseConfig (+ modules/nixos/)
  default.nix          # lib.foldl merge of all test files
  fixtures/
    mullet.txt         # hello / cowsay — for ft.mullet tests
    facter.json        # minimal hardware stub — for ft.hardware.facter tests
  core-boot.nix        # ft.system.core + ft.users
  tailscale-load.nix   # ft.services.tailscale
  podman-rootless.nix  # ft.services.podmanRootless
  printing.nix         # ft.services.printing
  keepass.nix          # ft.keepass
  nix-index.nix        # ft.programs.nixIndex
  virt.nix             # ft.system.virt
  nfs-framework.nix    # ft.services.nfs
  cli.nix              # ft.cli
  apps.nix             # ft.apps (consumer)
  mullet.nix           # ft.mullet (consumer)
  facter.nix           # ft.hardware.facter (consumer)
  nfs-consumer.nix     # ft.nfs (consumer)
  rclone.nix           # ft.rclone (consumer)
  local-ai.nix         # ft.services.localAi (consumer)
  containers.nix       # ft.containers (consumer)
```

### Adding a test (required for every new module)

Use `baseConfig` for framework modules, `consumerBaseConfig` for modules in `modules/nixos/`. Every test must assert at least one **runtime effect** — service active, binary on PATH, config file written. Checking only that the module evaluates is not sufficient.

```nix
{ inputs, nixpkgs }:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) baseConfig;
in
{
  vm-my-feature-load = pkgs.testers.runNixOSTest {
    name = "ft-my-feature-load";
    nodes.machine = { ... }: {
      imports = [ baseConfig ];
      ft.my.feature.enable = true;
    };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("my-feature.service")
    '';
  };
}
```

After adding the file, register it in `tests/vm/default.nix` and add `.#vm-my-feature-load` to `.github/workflows/vm-tests.yml`.

### Excluded modules (no VM test required)

| Module | Reason |
|---|---|
| `ft.kernel.cachyos` | Requires nix-cachyos binary cache |
| `ft.security.sops` | Requires SSH host key + encrypted secrets file |
| `ft.boot.limine` | Bootloader testing conflicts with QEMU |
| `ft.desktop.cosmic`, `ft.desktop.plasma` | Too heavyweight for CI |
| `ft.profiles.gaming` | Too heavyweight (Steam, Jovian-NixOS) |
| `ft.services.bulkPool` | Requires physical drives with specific labels |
| `ft.hardware.yubikey` | Requires physical YubiKey |
| `ft.services.komodo` | Depends on sops secrets |
| `ft.hardware.gpu` | No GPU hardware in QEMU; module is a no-op |

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
- Merge a module PR only after a corresponding VM smoke test in `ft-home/tests/vm/` passes, unless the module is explicitly exempt (hardware-dependent, binary cache-dependent, or secrets infrastructure).
- Write a VM test that only checks evaluation — every test must assert at least one runtime effect (service active, binary on PATH, config file present).
