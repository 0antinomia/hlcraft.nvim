# hlcraft.nvim

[中文文档](./README.zh.md)

`hlcraft.nvim` is an interactive highlight explorer and override manager for Neovim.

It gives you one place to inspect highlight groups, search by name or color, edit overrides, and persist the result as TOML files.

It also works well as a unified control surface for your Neovim highlights. And if you want, you can absolutely use it like a "theme" plugin: one whose final look is shaped entirely by you.

A practical workflow is to ask AI to turn a colorscheme you already like into hlcraft persistence files, then keep refining it from there. Or skip that and build your own style from scratch. Either way, the end result stays in your hands.

## Features

- Search highlight groups by name
- Search highlight groups by color similarity
- Inspect resolved `fg`, `bg`, `sp`, links, source and attributes
- Edit overrides in a detail editor
- Persist overrides across sessions
- Reapply persisted overrides after colorscheme changes
- Zero external dependencies

## Requirements

- Neovim `>= 0.10.0`

## Installation

### lazy.nvim

```lua
{
  '0antinomia/hlcraft.nvim',
  config = function()
    require('hlcraft').setup()
  end,
}
```

### Minimal setup

```lua
require('hlcraft').setup()
```

The plugin also registers the `:Hlcraft` command automatically.

## Configuration

Default configuration:

```lua
require('hlcraft').setup({
  from_none = {
    enabled = false,
    scope = 'extended',
  },
  threshold = 100,
  include_sp_in_color_search = false,
  persist_dir = vim.fn.stdpath('config') .. '/.hlcraft',
  reapply_events = {
    enabled = true,
    events = {
      'ColorScheme',
    },
  },
  dynamic = {
    enabled = false,
    interval_ms = 80,
  },
  debounce_ms = 100,
  preview_key = 'z',
})
```

### Options

#### `from_none`

Controls whether hlcraft applies a transparent baseline preset before your own runtime and persisted overrides.

```lua
from_none = {
  enabled = false,
  scope = 'extended',
}
```

- `enabled`: whether the preset is active
- `scope = 'core'`: only clears a smaller set of foundational groups such as `Normal`, `NormalFloat`, `SignColumn`
- `scope = 'extended'`: also clears more UI groups such as popup menu and winbar related highlights

Use this when you want hlcraft to maintain a transparent background setup for you.

If you want the quickest path to a transparent Neovim look, this is probably the setting you want.

#### `threshold`

Default distance threshold used by color search.

```lua
threshold = 100
```

Color search uses RGB Euclidean distance. Lower values are stricter. Higher values return broader matches.

#### `include_sp_in_color_search`

Controls whether the `sp` field participates in color matching.

```lua
include_sp_in_color_search = false
```

When enabled, highlight groups whose special color matches the query can also appear in the results. This is mainly useful for underline- and undercurl-heavy colorschemes.

#### `persist_dir`

Directory used to store persisted override files.

```lua
persist_dir = vim.fn.stdpath('config') .. '/.hlcraft'
```

By default, hlcraft stores persistence data in a hidden directory under your Neovim config directory. It may create multiple TOML files there.

#### `reapply_events`

Events that trigger automatic replay of persisted overrides.

```lua
reapply_events = {
  enabled = true,
  events = {
    'ColorScheme',
  },
}
```

You can provide either plain event names or structured entries inside `events`:

```lua
reapply_events = {
  enabled = true,
  events = {
    'ColorScheme',
    { event = 'SessionLoadPost', once = false },
  },
}
```

Structured entries support:

- `event`: autocmd event name
- `pattern`: optional autocmd pattern
- `once`: whether the autocmd should run only once

Set `enabled = false` to disable automatic replay entirely.

#### `dynamic`

Controls whether saved dynamic color overrides are animated at runtime.

```lua
dynamic = {
  enabled = false,
  interval_ms = 80,
}
```

- `enabled`: when `false`, dynamic configuration is loaded and saved but does not animate
- `interval_ms`: animation tick interval in milliseconds

Dynamic color configuration is edited from the existing `FG`, `BG`, and `SP` editors. Press `d` in a color editor to toggle dynamic mode, `m` to switch between `rgb` and `breath`, and `+` / `-` to change speed.

#### `debounce_ms`

Debounce delay for search input updates.

```lua
debounce_ms = 100
```

- `0`: disable debounce and update immediately
- `> 0`: wait the given milliseconds before recomputing results during typing

#### `preview_key`

Temporary flash key used to identify the currently selected highlight group.

```lua
preview_key = 'z'
```

This key is installed as a temporary global normal-mode mapping while the hlcraft workspace is open, so it still works after switching to another window. Once the workspace closes, the mapping is removed.

Set it to `false` to disable the feature entirely.

## Usage

Open the workspace:

```vim
:Hlcraft
```

### Search

The top area contains two inputs:

- `name`: filters by case-insensitive substring match on highlight group names
- `color`: filters by color similarity

The two filters can be combined.

Color queries accept:

- `#RRGGBB`
- `NONE`

`NONE` matches groups whose resolved color is unset. By default this checks `fg` and `bg`. If `include_sp_in_color_search` is enabled, it also checks `sp`.

## Persistence

Persisted overrides are written under:

```lua
vim.fn.stdpath('config') .. '/.hlcraft'
```

Each file stores one top-level TOML section. Section names come from groups you explicitly select or create in the detail view. If an override has no group, hlcraft asks you to choose or create one before saving.

Dynamic color settings are stored as hlcraft-specific flat keys such as `dyn_fg_mode` and `dyn_fg_speed`.

Persisted overrides are loaded during `setup()` and replayed again on configured `reapply_events`.

## Health Check

Run:

```vim
:checkhealth hlcraft
```

This checks:

- Neovim version compatibility
- persistence directory availability
- persistence directory writability
- TOML parse integrity
