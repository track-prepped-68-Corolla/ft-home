# HM Refactor Todo

### 🏗️ Flake Architecture & Core Structure
- [x] wire up all flake inputs
- [x] create code to send flake outputs to magic folder functions
- [x] create magic folder function for hosts
- [x] create magic folder function for homes
- [x] create magic collator file for host modules
- [x] create magic collator file for home modules
- [x] create a home module for magic mkoutofstoresymlink folder functions
- [x] Externalize Generator Logic

### 📦 Module Management & Migration
- [x] purge modules and bring back mvp
- [x] **Import modules:**
  - [x] Audit the purged modules to determine which are required for the MVP.
  - [x] Import and verify core system-level (NixOS) modules.
  - [x] Import and verify core user-level (Home Manager) modules.
- [ ] **Convert any applicable modules from system level to user level:**
  - [ ] Identify which existing system modules only affect user environments.
  - [ ] Rewrite Nix expressions to use Home Manager options (e.g., `home.packages`, `home.file`).
  - [ ] Remove the old system-level configurations and test the user-level replacements.
- [ ] create a user level komodo module
- [x] **Implement “The Mullet” (Imperative Escape Hatch) — consumer side (ft-home):**
  - [x] Create `mullet.nix` module to ingest a flat text file (`mullet.txt`).
  - [x] Add config option to specify the path of `mullet.txt`.
  - [x] Map parsed text strings to `pkgs` and append to `environment.systemPackages` or `home.packages`.
- [ ] **Port “The Mullet” to the framework (fast-track-nix):**
  - [ ] Move `mullet.nix` logic into `fast-track-nix/modules/nixos/` as a proper `ft.mullet` option module.
  - [ ] Consumer (`ft-home`) enables `ft.mullet` and sets `ft.mullet.filePath` to their local `mullet.txt`; remove the local `mullet.nix`.
  - [ ] Update `mullet.just` hardcoded `MULLET_FILE` path to use the configured option path.
  - [ ] Export `nixosModules.mullet` as a standalone output in `fast-track-nix/flake.nix`.

### 👁️ Ergonomics & Accessibility (The “Chaotic Good” Stack)
- [ ] **Visual & Circadian Automation:**
  - [ ] Build the Matugen to Stylix pipeline for Base24 HCT contrast manipulation.
  - [ ] Integrate Gammastep for circadian color temperature shifting.
  - [ ] Configure `ddcutil` for hardware backlight control (with a silent fallback to Wayland brightness shaders).
- [ ] **Typography & Spatial Scaling:**
  - [x] Set Atkinson Hyperlegible (or Lexend) as the default system font via Stylix.
  - [ ] Script dynamic UI padding and text scaling based on time of day/fatigue levels.
- [ ] **Kinematics & Input (RSI Prevention):**
  - [ ] Set up `kanata` for kernel-level Home Row Mods.
  - [ ] Integrate `warpd` for geometric, keyboard-driven mouse emulation.
- [ ] **Auditory & Attention Management:**
  - [ ] Set up local offline STT (Whisper.cpp) and TTS (Piper) tied to global Wayland hotkeys.
  - [ ] Create a DBus notification interceptor script (`mako` or `dunst`) for context-aware routing and squashing during deep work.

### 👥 User Provisioning & Environment
- [ ] create a script that creates generic home folders for new users
- [ ] create a script that runs the first home manager switch on users that don’t have a home manager profile yet
- [ ] create mackup dot file script

### 💻 Hardware, Boot & Vendor Support
- [x] swap bootloader to limine
- [x] remove lanzaboote from inputs and add facter
- [x] set up facter modules *(done in ft-home consumer)*
- [x] create GPU module for facter *(done in ft-home consumer)*
- [ ] **Port facter and GPU modules to the fast-track-nix framework:**
  - [ ] Move `facter.nix` into `fast-track-nix/modules/nixos/hardware/` as an `ft.hardware.facter` option module.
  - [ ] Move `gpu.nix` into `fast-track-nix/modules/nixos/hardware/` with generic AMD/Intel/NVIDIA/Integrated vendor detection.
  - [ ] Remove local copies from `ft-home` once framework versions are stable.
- [ ] enable Asus support
- [ ] **Look into supporting other vendors:**
  - [ ] Review `nixos-hardware` for common vendor profiles (Lenovo, Dell, etc.).
  - [ ] Scaffold a generic vendor module structure to easily toggle vendor-specific quirks.
  - [ ] Implement and test at least one alternative vendor configuration.

### 🔐 System Services, Security & Automation
- [x] bring in just scripts and modify as needed
- [ ] setup systemd userd
- [ ] **Setup sops-nix scaffolding (The Silent Setup):**
  - [x] Add `sops-nix` to flake inputs and wire it into the core module system.
  - [ ] Implement `ssh-to-age` pipeline to derive SOPS decryption keys silently from the target’s SSH host keys.
  - [ ] Create an automated Diceware generator to create high-entropy passphrases for initial user creation.
  - [ ] Script the programmatic creation of a KeePassXC (`.kdbx`) vault using the Diceware password as the master key.
  - [ ] Configure the repo’s `.gitignore` to explicitly allow the `.kdbx` vault file for local version-controlled redundancy.
  - [ ] Implement conditional logic (`mkIf cfg.enableSecrets`) so the system degrades gracefully if secrets aren’t ready.

### 🌐 Public Release Preparation (Two-Repo Architecture)
**🧹 Sanitization & Security**
- [ ] Audit all modules for hardcoded personal data (usernames, hostnames, absolute local paths, private IPs).
  - [ ] Fix hardcoded wallpaper path in `stylix.nix` (`../../homes/guest/wallpapers/default.png`) — expose as a consumer-supplied option instead.
- [ ] Replace hardcoded user strings with variable references (e.g., `config.home.username`).
- [ ] Move highly specific private modules out of the repo entirely.
- [ ] **Crucial:** Reset Git history (delete `.git` and re-run `git init`) right before publishing.

**🔌 Flake API & Exports**
- [x] Move purely functional code into a dedicated `lib/` (`lib/generator.nix`).
- [ ] Export library functions under `outputs.lib` in `flake.nix`. *(currently only `lib.mkFlake` is exported — expand with additional utility functions)*
- [x] Export module collators via `nixosModules.default` and `homeManagerModules.default`.
- [ ] Export `nixosModules.mullet` as a standalone backend feature. *(blocked on Mullet framework port)*
- [ ] Export the `ft` CLI wrapper via `packages.default` using `writeShellApplication`.
  - [ ] Inject `runtimeInputs` (`just`, `glow`, `nh`, `git`, `delta`, `trufflehog`) to ensure zero global dependency footprint for the user.
- [ ] **External Base Path:** Refactor `mkOutOfStoreSymlink` to accept an `absoluteBasePath` from the consumer.

**📖 Documentation & Onboarding**
- [ ] Add inline comments to `lib` functions.
- [x] Write `README.md` explaining the framework’s consumption.
- [ ] Create `template/` directory for the “Private Repo” skeleton.
  - [ ] Ensure template includes a blank `mullet.txt` and a consumer `flake.nix` wired to the upstream tool.

**✨ Code Polish & Linting**
- [x] Run a standard formatter. *(treefmt + nixfmt wired into `nix fmt` and CI checks)*
- [x] Run a linter. *(statix + deadnix wired into `nix flake check` CI gate)*
- [ ] Clean up and standardize the `justfile` scripts. *(core workflow is solid; dashboard, routing, and init commands still needed)*

### 👾 Just files & Deployment Orchestration
- [x] pass flake directory back and forth between nh and the repo *(resolved: `nh os switch .` uses cwd; no separate variable needed)*
- [ ] make helper scripts for imperative steps
- [ ] **Dashboard Rendering Engine:** Implement the custom `##@` dynamic parsing hack using `sed`/`grep`, piped into `glow` for the default `ft` display.
- [ ] **Agnostic Build Routing:**
  - [ ] Create `ft os` to dynamically detect and run either `nh os switch` or `nh darwin switch`.
  - [ ] Create `ft home` to explicitly trigger `nh home switch`.
- [ ] **Graceful Degradation Guardrails:** Wrap all version control integrations (`git diff`, `delta`, auto-commits) in `git rev-parse --is-inside-work-tree` checks to prevent crashes in uninitialized directories.
- [ ] **The Bootstrapper (`init`):** Write `ft init` to safely scaffold `mullet.txt` and coach the user on exporting the `$FLAKE` environment variable.
- [ ] Write a wrapper for the Lix fork of the Determinate Systems installer.
- [ ] Create `just bootstrap-secrets <host>` to handle Diceware, SOPS, and Vault generation.
- [ ] Create `just deploy <host>` utilizing `nixos-anywhere`.
- [ ] Create `just init-remote` for secure upstream Git forge setup.
- [ ] **Create `just dump-logs`:** Build a telemetry script that sanitizes and packages `facter` output, `dmesg`, and core logs into an automated payload (e.g., via a GitHub issue URL generator or encrypted pastebin) to eliminate PR friction.
