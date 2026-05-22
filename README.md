# ft-home

Personal NixOS + Home Manager configuration, built on the [fast-track-nix](https://github.com/track-prepped-68-corolla/fast-track-nix) framework.

## What this is

This is a **consumer repo** — it contains machine and user configurations that call `ft-home.lib.mkFlake` and get fully-assembled NixOS and Home Manager outputs in return. The framework that supplies all the modules lives in a separate repo (`fast-track-nix`).

```
flake.nix          ← one delegation: ft-home.lib.mkFlake inputs
machines/          ← one directory per host
users/             ← one directory per user
modules/           ← consumer-local modules (staging area for framework candidates)
scripts/           ← justfile task runner split into: sys, bootstrap, mullet, store, drives
var/secrets/       ← sops-nix key config (.sops.yaml)
```

## Machines

| Machine | Description |
|---------|-------------|
| `strix` | Daily-driver desktop |
| `strix-vm` | Local NixOS VM for testing |

## Users

| User | Role |
|------|------|
| `admin` | Safety-net administrative account |
| `guest` | Minimal unprivileged account |
| `joe` | Primary user account |

## Getting started (new machine)

See `CLAUDE.md` for the full provisioning workflow and developer reference, and `eject.md` if you want to take ownership of the flake wiring away from the framework generator.

## Intended software

See `Ft-home software.md` for the full target application stack.
