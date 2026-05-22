# Fast Track UI — App Plan

## Vision

A Trolley-packaged TUI app that gives gamers and regular PC users a polished interface
for managing their NixOS system. No terminal knowledge required. The just scripts remain
available as a power-user CLI; the TUI is the primary interface for everyone else.

---

## Scope

| Area | What it covers |
|---|---|
| **OOBE / Provisioning** | First-boot wizard: git init, machine scaffold, secrets, nixos-anywhere deploy |
| **Maintenance** | Switch, pull, rollback, clean — with streaming output and package diff views |
| **Package Management** | Mullet: fuzzy search nixpkgs, add/remove with live list, apply |
| **Module Toggles** | Split-pane: checkboxes/inputs on left, live Nix code preview on right |

---

## Architecture

### Layer 1 — Python backend (headless operations)

A Python package (`ft/`) that implements all operations as functions. No inline prompts,
no terminal assumptions. Accepts parameters in, streams structured output out.

```
ft/
  ops/
    sys.py        # switch, pull, rollback, clean, fmt, check
    bootstrap.py  # git_init, add_machine, secrets_init, generate_facts, deploy
    mullet.py     # search, add, remove, list, clear
    options.py    # nix eval introspection, ui-settings.nix read/write
  tui/
    app.py        # Textual app entry point
    screens/
      dashboard.py
      provisioning.py
      packages.py
      modules.py
```

All subprocess calls are async (`asyncio.create_subprocess_exec`) so Textual can stream
output into the UI without blocking.

### Layer 2 — Textual TUI

Built with [Textual](https://textual.textualize.io/). Each scope area is a screen.
The dashboard is the home screen with navigation to all areas.

### Layer 3 — Trolley packaging

The Python app + libghostty bundled into a portable application via Trolley. No Python
installation required on the target machine.

---

## Module Toggle Architecture

### The problem

Editing `machines/<name>/default.nix` directly is fragile — parsing and rewriting Nix
ASTs is unreliable and produces machine-generated-looking code.

### The solution: `ui-settings.nix` overlay

Each machine has a separate file managed exclusively by the TUI:

```
machines/<name>/
├── default.nix       ← hand-edited, never touched by the TUI
├── ui-settings.nix   ← generated and owned by the TUI
└── modules/
```

`default.nix` imports it:

```nix
imports = [
  ./ui-settings.nix
  ./modules
  ../../modules/nixos
];
```

`ui-settings.nix` contains only the options the user has explicitly set:

```nix
{
  ft.desktop.cosmic.enable = true;
  ft.services.printing.enable = true;
  ft.kernel.cachyos.enable = false;
}
```

This is trivial to generate from a Python dict. Hand-edits to `default.nix` are never
at risk. Merge conflicts are impossible because the TUI never touches `default.nix`.

### Option discovery via `nix eval`

The full `ft.*` option tree — including types, descriptions, and current values — is
available via:

```bash
nix eval .#nixosConfigurations.<name>.options.ft --json
nix eval .#nixosConfigurations.<name>.config.ft --json
```

The TUI calls this once at startup (with a loading screen), caches the result, and
generates widgets dynamically:

| Nix type | Widget |
|---|---|
| `bool` | Checkbox |
| `str` / `path` | Text input |
| `enum` | Dropdown |
| `nullOr bool` | Three-state toggle |
| `int` | Numeric input |

Because option metadata comes from the framework, new `ft.*` options added to
fast-track-nix appear in the UI automatically with no app changes.

### Live code preview

The right pane renders `ui-settings.nix` with syntax highlighting (`rich.syntax.Syntax`)
and updates on every widget change event — purely from in-memory state, no re-evaluation.
Changes are written to disk only when the user confirms.

---

## Key Design Constraints

**Async from the start.** `nh os switch` runs for minutes. Every subprocess call must
be async so the UI stays alive and can stream output. Do not use `subprocess.run()`.

**`nix eval` is slow.** Cache the option tree at startup. Never call `nix eval` in
response to user input — all UI interactions update in-memory state only.

**Non-technical audience.** Error messages must be human-readable. No raw Nix evaluation
errors surfaced directly. Wrap failures with context ("Build failed — see details below").

**The just scripts stay.** Power users keep their CLI. The Python backend is shared;
`just` recipes call the same Python module for operations that warrant it, or remain
as thin shell wrappers for simple cases.

---

## Development Sequence

1. **Python backend** — implement `ops/` modules as pure functions, fully testable
   without a TUI. Start with `sys.py` (switch, pull) since it covers daily use.

2. **`ui-settings.nix` pattern** — establish the overlay file format and the
   read/write logic in `options.py`. Add `ui-settings.nix` import to machine configs.

3. **Option introspection** — implement `options.py` discovery via `nix eval`.
   Handle non-serializable types gracefully (filter or fall back to raw string input).

4. **Module toggle panel** — the split-pane screen. This is the centrepiece feature;
   build it early to validate the architecture before investing in other screens.

5. **Maintenance screens** — switch, pull, rollback with streaming output views.

6. **Package manager screen** — mullet search/add/remove with fuzzy filtering.

7. **OOBE wizard** — provisioning flow as a Textual screen stack. Each step is a
   screen; completion of one unlocks the next.

8. **Trolley packaging** — bundle and test as a portable application.

---

## fast-track-nix Dependencies

The framework needs to hold its end for option introspection to work well:

- Every `ft.*` option must have a `description` (already enforced by CLAUDE.md).
- Option types must be concrete (`bool`, `str`, `enum`) rather than `anything` where
  possible — vague types produce vague widgets.
- The mullet module should be ported to the framework (already tracked in Todo.md)
  so the TUI can manage it uniformly with other options.
