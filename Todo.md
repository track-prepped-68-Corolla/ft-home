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
- [x] **Implement "The Mullet" (Imperative Escape Hatch) — consumer side (ft-home):**
  - [x] Create `mullet.nix` module to ingest a flat text file (`mullet.txt`).
  - [x] Add config option to specify the path of `mullet.txt`.
  - [x] Map parsed text strings to `pkgs` and append to `environment.systemPackages` or `home.packages`.
- [ ] **Port "The Mullet" to the framework (fast-track-nix):**
  - [ ] Move `mullet.nix` logic into `fast-track-nix/modules/nixos/` as a proper `ft.mullet` option module.
  - [ ] Consumer (`ft-home`) enables `ft.mullet` and sets `ft.mullet.filePath` to their local `mullet.txt`; remove the local `mullet.nix`.
  - [ ] Update `mullet.just` hardcoded `MULLET_FILE` path to use the configured option path.
  - [ ] Export `nixosModules.mullet` as a standalone output in `fast-track-nix/flake.nix`.

### 👁️ Ergonomics & Accessibility (The "Chaotic Good" Stack)
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
- [ ] create a script that runs the first home manager switch on users that don't have a home manager profile yet
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
  - [ ] Implement `ssh-to-age` pipeline to derive SOPS decryption keys silently from the target's SSH host keys.
  - [ ] Create an automated Diceware generator to create high-entropy passphrases for initial user creation.
  - [ ] Script the programmatic creation of a KeePassXC (`.kdbx`) vault using the Diceware password as the master key.
  - [ ] Configure the repo's `.gitignore` to explicitly allow the `.kdbx` vault file for local version-controlled redundancy.
  - [ ] Implement conditional logic (`mkIf cfg.enableSecrets`) so the system degrades gracefully if secrets aren't ready.

### 🌐 Public Release Preparation (Two-Repo Architecture)
**🧹 Sanitization & Security**
- [ ] Audit all modules for hardcoded personal data (usernames, hostnames, absolute local paths, private IPs).
  - [ ] Fix hardcoded wallpaper path in `stylix.nix` (`../../homes/guest/wallpapers/default.png`) — expose as a consumer-supplied option instead.
- [ ] Replace hardcoded user strings with variable references (e.g., `config.home.username`).
- [ ] Move highly specific private modules out of the repo entirely.
- [ ] **Crucial:** Reset Git history (delete `.git` and re-run `git init`) right before publishing.
- [ ] **Remove hard-coded defaults from `fast-track-nix` framework modules:**
  - [ ] `ft.system.core`: Remove the `time.timeZone` default (`"America/New_York"`) — require consumers to set their own timezone explicitly.
  - [ ] `ft.system.core`: Remove `system.stateVersion` from the framework — consumers must own this value to control when NixOS upgrade paths activate.
  - [ ] `ft.users`: Remove the hard-coded `initialPassword = "snp"` for the `admin` user — require password to be supplied via sops or an explicit consumer option.
  - [ ] `ft.users`: Remove the hard-coded U2F key for `admin` from the PAM `authfile` — the framework should ship with no pre-registered keys; consumers supply their own via `ft.hardware.yubikey.u2fMapping`.

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
- [x] Write `README.md` explaining the framework's consumption.
- [ ] Create `template/` directory for the "Private Repo" skeleton.
  - [ ] Ensure template includes a blank `mullet.txt` and a consumer `flake.nix` wired to the upstream tool.

**✨ Code Polish & Linting**
- [x] Run a standard formatter. *(treefmt + nixfmt wired into `nix fmt` and CI checks)*
- [x] Run a linter. *(statix + deadnix wired into `nix flake check` CI gate)*
- [x] Clean up and standardize the `justfile` scripts:
  - [x] Delete legacy `.justfile`; make `ft.just` a thin entry point (imports + aliases only).
  - [x] Split into modules: `sys.just` (daily driver), `bootstrap.just` (provisioning), `mullet.just` (packages), `store.just` (dotfiles, experimental).
  - [x] Fix `add-machine` template to match actual machine structure (`modules/` hub, `var/` for facter).
  - [x] Fix `mullet.just` path — moved `mullet.txt` to `users/<user>/var/mullet.txt`; path now uses `env_var("USER")`.
  - [x] Update `machines/strix/default.nix` with explicit `ft.mullet.sourcePath`.
  - [x] Port `home-switch` with correct just parameter syntax (was broken using `$1`/`$2`).
  - [x] Fix secrets and bootstrap paths to match `var/secrets/` layout.

### 👾 Scripts & CLI (remaining)
- [ ] Write a wrapper for the Lix fork of the Determinate Systems installer.
- [ ] **Graceful Degradation:** Wrap git integrations (`git diff`, `delta`, auto-commits) in `git rev-parse --is-inside-work-tree` checks.

### 🖥️ Fast Track TUI App (Trolley)
See `scripts/plan.md` for full architecture and development sequence.

**Target audience:** gamers and regular PC users who prefer not to touch the terminal.
**Packaging:** Trolley (bundles libghostty into a portable application).
**Framework:** Python + Textual. Async subprocesses throughout.

- [ ] **`ui-settings.nix` overlay pattern**
  - [ ] Add `import ./ui-settings.nix` to machine `default.nix` templates (update `add-machine` scaffold in `bootstrap.just`).
  - [ ] Create initial empty `ui-settings.nix` stubs for existing machines (`strix`, `strix-vm`).
- [ ] **Python backend (`ft/ops/`)**
  - [ ] `sys.py` — switch, pull, rollback, clean, fmt, check (async subprocess, streaming output).
  - [ ] `bootstrap.py` — git_init, add_machine, secrets_init, generate_facts, deploy.
  - [ ] `mullet.py` — search (nix-index + nix search), add, remove, list, clear.
  - [ ] `options.py` — option discovery via `nix eval`, `ui-settings.nix` read/write.
- [ ] **Module toggle panel** (split-pane: checkboxes left, live Nix preview right)
  - [ ] Option tree from `nix eval .#nixosConfigurations.<name>.options.ft --json`.
  - [ ] Dynamic widget generation from Nix option types (bool→checkbox, str→input, enum→dropdown).
  - [ ] Live `ui-settings.nix` preview with syntax highlighting.
  - [ ] Write-on-confirm; in-memory updates only until confirmed.
- [ ] **Maintenance screen** — switch/pull/rollback with streaming output and package diff view.
- [ ] **Package manager screen** — mullet with fuzzy search, add/remove, apply.
- [ ] **OOBE / provisioning wizard** — screen stack: git-init → add-machine → secrets-init → deploy.
- [ ] **Dashboard** — home screen with navigation, system status summary.
- [ ] **Trolley packaging** — bundle Python app + libghostty into portable application.
