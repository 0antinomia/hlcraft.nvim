# Architecture

[Index](./index.md) | [中文](../zh/architecture.md)

This document describes the current project structure and the responsibility of each major module.

## Runtime Entry

```text
plugin/hlcraft.lua
```

This is the Neovim runtime entry file. It only registers `:Hlcraft`. The command loads `require('hlcraft')`, performs setup if needed, and opens the workspace.

Business logic should not live in `plugin/`.

## Public API

```text
lua/hlcraft/init.lua
```

This is the public Lua facade. It exposes:

- `setup(opts)`
- `is_setup()`
- `open(opts)`
- highlight search helpers
- the override service facade

Internal modules are grouped under `config`, `core`, `dynamic`, `engine`, `persistence`, and `ui`.

## Configuration

```text
lua/hlcraft/config.lua
lua/hlcraft/config/
```

The config layer validates and normalizes user options before initialization. The schema is declarative:

- `spec.lua`: option defaults and known key sets.
- `validate.lua`: strict validation and error messages.
- `normalize.lua`: trims and normalizes accepted values.
- `schema.lua`: combines spec, validation, normalization, and defaults.

## Core

```text
lua/hlcraft/core/
```

Core modules handle pure highlight and value logic:

- Color parsing and conversion.
- Highlight entry normalization.
- Highlight names and field metadata.
- Search by name and color.
- Tables, timers, and numeric helpers.

These modules should avoid UI state and persistence side effects.

## Dynamic Colors

```text
lua/hlcraft/dynamic/
```

Dynamic color modules define the declarative animation model:

- Constants and model validation.
- Presets.
- Timeline sampling.
- Numeric transforms.
- Runtime application loop.

The runtime updates highlight group channels over time. The model remains serializable and independent of UI state.

## Engine

```text
lua/hlcraft/engine/
```

The engine owns override state and mutation behavior:

- Draft and persisted stores.
- Patch validation and normalization.
- Snapshot and restore behavior.
- Applying overrides to Neovim.
- Lifecycle and reapply hooks.

The UI talks to the engine through service-level functions rather than mutating store tables directly.

## Persistence

```text
lua/hlcraft/persistence/
```

Persistence owns TOML encoding, parsing, file scanning, normalization, and repository operations.

The repository boundary is responsible for loading saved state into normalized tables and saving normalized overrides back to TOML.

## UI

```text
lua/hlcraft/ui.lua
lua/hlcraft/ui/
```

The UI layer owns the workbench:

- Instance lifecycle.
- Window and buffer management.
- Search and detail scenes.
- Field editors.
- Input handling.
- Rendering.
- Keymaps and prompts.

The top-level `lua/hlcraft/ui.lua` file is a facade that manages named UI instances.

## Tests

```text
tests/
```

Tests mirror the module boundaries. `tests/run_all.lua` lists every test file and fails if a new test file is not included, except for helper files that are intentionally ignored.

The suite is run with:

```bash
nix develop -c nvim --headless -u NONE -c 'set rtp+=.' -l tests/run_all.lua
```
