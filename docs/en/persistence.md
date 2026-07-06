# Persistence

[Index](./index.md) | [中文](../zh/persistence.md)

hlcraft persists saved overrides as TOML files. The files are intended to be readable, editable, and easy to version with your Neovim configuration.

## Directory

The default persistence directory is:

```lua
vim.fn.stdpath('config') .. '/hlcraft'
```

Configure it with:

```lua
require('hlcraft').setup({
  persistence = {
    dir = vim.fn.stdpath('config') .. '/hlcraft',
  },
})
```

## TOML Sections

Each persisted file stores one top-level TOML section. Section names come from groups you choose or create in the workspace.

```toml
["ui.base"]
"Normal" = { fg = "#d7d7ff", bg = "NONE" }
"NormalFloat" = { bg = "NONE" }
```

A highlight entry can contain:

- Color fields: `fg`, `bg`, `sp`.
- Style fields: `bold`, `italic`, `underline`, `undercurl`, and related Neovim highlight flags.
- Numeric fields such as `blend`.
- `dynamic` channel settings.

## Groups

Groups are persistence sections, not Neovim highlight groups. They let you organize saved overrides into separate TOML files.

Examples:

```text
base
ui.popup
syntax.lua
dynamic.effects
```

If a highlight has no persistence group, hlcraft asks you to choose or create one before saving.

## Dynamic Colors

Dynamic settings live inside the same highlight entry:

```toml
["demo.group"]
"Normal" = { fg = "#d7d7ff", dynamic = { fg = { version = 1, preset = "pulse", duration = 2000, loop = "pingpong", timeline = [{ at = 0, color = "base" }, { at = 1, color = "#ff6699" }] } } }
```

The persisted form uses the same declarative model as the raw JSON editor.

## Load And Replay

Persisted overrides are loaded during `require('hlcraft').setup()`.

They can also be replayed on configured events:

```lua
persistence = {
  reapply_events = {
    enabled = true,
    events = {
      'ColorScheme',
    },
  },
}
```

This is useful because colorscheme changes usually rewrite highlight groups.

## Manual Editing

Manual editing is supported, but the schema is strict:

- Unknown fields are rejected.
- Highlight names must be valid names.
- Color values must be valid colors or `NONE`.
- Dynamic channels must normalize successfully.
- Duplicate highlight entries across loaded files are rejected.

After editing TOML manually, run:

```vim
:checkhealth hlcraft
```

The health check validates that persisted data can be parsed and normalized.

## Save Semantics

Saving writes the current draft override for a highlight group to its selected persistence group. Draft changes that are never saved remain session-local.

When a saved override becomes empty, hlcraft cleans up stale TOML entries and removes stale files that no longer correspond to active groups.
