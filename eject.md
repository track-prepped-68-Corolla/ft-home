# Ejecting from the ft-home Framework

This document is for users who want to move from delegating to `ft-home.lib.mkFlake` to owning their flake outputs directly — whether to take more control, learn standard NixOS wiring, or eventually drop the framework dependency entirely.

Nothing is trapped. The framework is standard NixOS and Home Manager modules wrapped in a generator. This guide shows you how to unwrap it.

---

## Three Paths

### Path A — Hybrid (recommended)

Keep using all framework modules and `ft.*` options, but write your own `flake.nix` instead of delegating to `lib.mkFlake`. The framework already exports `nixosModules.default` and `homeManagerModules.default` as named flake outputs for exactly this purpose.

**What you gain:** Full visibility into flake wiring; no more implicit machine/user discovery.
**What you keep:** Every `ft.*` option works unchanged.
**Effort:** ~1 hour.

### Path B — Full standalone

Copy `fast-track-nix/modules/` into this repo and remove the `ft-home` input entirely. You own and maintain all modules going forward.

**What you gain:** Zero external framework dependency.
**What you trade:** Framework module updates no longer flow in automatically.
**Effort:** 3–6 hours.

### Path C — Fresh start

Start a new flake from scratch using standard NixOS resources. Reference the files in this repo for what to bring along — packages, dotfiles, disk layout, secrets config, etc.

**Best for:** Learning standard NixOS patterns from the ground up.
**Effort:** A weekend.

---

## Path A: Step by Step

Replace the single delegation line in `flake.nix` with explicit outputs that import the framework modules by name.

**Before:**

```nix
outputs = inputs@{ ft-home, ... }: ft-home.lib.mkFlake inputs;
```

**After:**

```nix
outputs =
  { self, nixpkgs, home-manager, ft-home, ... }@inputs:
  {
    nixosConfigurations.strix = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        ft-home.nixosModules.default   # all ft.* options still available
        ./machines/strix
        { nixpkgs.hostPlatform = "x86_64-linux"; }
      ];
    };

    homeConfigurations."joe@x86_64-linux" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      extraSpecialArgs = { inherit inputs; };
      modules = [
        ft-home.homeManagerModules.default
        ./users/joe
      ];
    };
  };
```

Add one `nixosConfigurations` block per machine in `machines/` and one `homeConfigurations` block per user/arch pair. The architecture string (`x86_64-linux`) comes from `machines/<name>/var/facter.json` → `facter.system`.

For each additional machine or user, repeat the pattern. If you run Home Manager standalone (no machine entry), hard-code the system string directly instead of reading `var/local/system`.

Verify after rewriting:

```
nix flake check
nix build .#nixosConfigurations.strix.config.system.build.toplevel
nix build .#homeConfigurations."joe@x86_64-linux".activationPackage
```

---

## Path B: Step by Step

**1. Copy the framework modules into this repo.**

Clone `fast-track-nix` locally, then:

```
cp -r fast-track-nix/modules/nixos ./modules/nixos-framework
cp -r fast-track-nix/modules/home  ./modules/home-framework
```

Merge with or replace the existing `modules/nixos/` and `modules/home/` as needed.

**2. Expand `flake.nix` inputs.** Remove `ft-home` and add its dependencies directly:

```nix
inputs = {
  nixpkgs.url         = "github:nixos/nixpkgs/nixos-unstable";
  nixpkgs-stable.url  = "github:nixos/nixpkgs/nixos-25.11";
  home-manager        = { url = "github:nix-community/home-manager";    inputs.nixpkgs.follows = "nixpkgs"; };
  sops-nix            = { url = "github:Mic92/sops-nix";               inputs.nixpkgs.follows = "nixpkgs"; };
  stylix              = { url = "github:danth/stylix";                 inputs.nixpkgs.follows = "nixpkgs"; };
  nixos-facter        = { url = "github:numtide/nixos-facter";         inputs.nixpkgs.follows = "nixpkgs"; };
  Disko               = { url = "github:nix-community/disko";          inputs.nixpkgs.follows = "nixpkgs"; };
  nix-cachyos         = { url = "github:xddxdd/nix-cachyos-kernel/release"; };
  # add others as needed: jovian-nixos, nur, nix-index-database, nixos-hardware
};
```

**3. Write explicit outputs**, importing your local copies instead of `ft-home.nixosModules.default`:

```nix
modules = [
  ./modules/nixos-framework  # copied framework modules
  ./modules/nixos            # your consumer modules
  ./machines/strix
  { nixpkgs.hostPlatform = "x86_64-linux"; }
];
```

**4. Update any import paths** in `machines/` or `users/` files that referenced locations that moved.

**5.** Run `nix flake check` to confirm everything wires up.

---

## Consumer-Specific Modules

Two modules in this repo are not part of the upstream framework — they live in `modules/` here and are already fully under your control regardless of which path you take:

**`ft.mullet`** — `modules/nixos/apps/mullet.nix`
Nothing to port. If you want to drop the `ft.*` wrapper entirely, convert the alias sourcing to `programs.zsh.initExtra` or `home.file` entries in your user config.

**`ft.localAi`** — `modules/nixos/services/local-ai.nix`
Same situation. To remove the wrapper, translate the llamafile and AnythingLLM setup to explicit `systemd.services.*` declarations.

---

## ft.* Option Reference

Quick reference for what each framework toggle enables, useful when reading module source or translating to plain NixOS/HM options under Path B or C. Source files are all under `modules/` in the `fast-track-nix` repo.

| ft option | What it enables | Default |
|-----------|----------------|---------|
| `ft.core.enable` | NetworkManager, Bluetooth, CUPS/Avahi, nix flakes, timezone, locale, core CLI packages | on |
| `ft.users.enable` | User creation via `mainuser`/`superUsers`/`normalUsers`, PAM U2F | on |
| `ft.terminal.enable` | kitty, ghostty, zsh, starship, zoxide, fzf, ~20 CLI packages, dotfile symlinks | on |
| `ft.cosmic.enable` | `services.desktopManager.cosmic`, `services.displayManager.cosmic-greeter`, `services.system76-scheduler`, `hardware.graphics` | off |
| `ft.plasma.enable` | KDE Plasma — see `modules/nixos/desktops/plasma.nix` | off |
| `ft.limine.enable` | Limine bootloader — see `modules/nixos/system/limine.nix` | off |
| `ft.cachyos.*` | CachyOS substituter + kernel package overlay — see `modules/nixos/system/kernel.nix` | off |
| `ft.gpu.enable` | `hardware.graphics` + vendor acceleration — see `modules/nixos/hardware/gpu.nix` | off |
| `ft.yubikey.enable` | `security.pam.u2f`, YubiKey udev rules | off |
| `ft.facter.*` | nixos-facter hardware-report module | off |
| `ft.sops.*` | sops-nix + age key derivation from SSH host keys | off |
| `ft.cli.enable` | Extended CLI profile — see `modules/nixos/profiles/` | off |
| `ft.keepass.enable` | `programs.keepassxc.enable` | off |
| `ft.lazyvim.enable` | `programs.neovim.enable` + LazyVim bootstrap | off |
| `ft.theme.enable` | stylix module + wallpaper and Base16 color scheme | off |
| `ft.mullet.*` | Shell alias ingestion from `mullet.txt` (consumer module) | off |
| `ft.localAi.*` | llamafile + AnythingLLM stack (consumer module) | off |

The three modules marked **on** activate without an explicit `enable = true` in your config. Setting `ft.<module>.enable = false` in your machine or user file disables them.
