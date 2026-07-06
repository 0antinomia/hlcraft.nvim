# hlcraft.nvim

[中文文档](./README.zh.md)

`hlcraft.nvim` is an interactive highlight workbench for Neovim.

It gives you one place to inspect highlight groups, search by name or color, edit overrides, preview the result, and persist your final decisions as TOML files.

You can use it as a practical highlight debugger, a personal theme-building layer, or a control surface for refining an existing colorscheme into something that is entirely yours.

## Features

- Search highlight groups by name.
- Search highlight groups by color similarity.
- Inspect resolved `fg`, `bg`, `sp`, links, source, and attributes.
- Edit color, style, blend, group, and dynamic color overrides.
- Persist overrides as readable TOML files.
- Reapply persisted overrides after colorscheme changes.
- Run without external dependencies.

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

### Minimal Setup

```lua
require('hlcraft').setup()
```

Open the workbench:

```vim
:Hlcraft
```

## Documentation

- [Documentation Home](./docs/en/index.md)
- [Configuration](./docs/en/configuration.md)
- [Workspace](./docs/en/workspace.md)
- [Dynamic Colors](./docs/en/dynamic-colors.md)
- [Persistence](./docs/en/persistence.md)
- [Architecture](./docs/en/architecture.md)

## Quick Configuration

```lua
require('hlcraft').setup({
  transparent = {
    enabled = false,
    scope = 'extended',
  },
  search = {
    threshold = 100,
    include_sp = false,
    debounce_ms = 100,
  },
  persistence = {
    dir = vim.fn.stdpath('config') .. '/hlcraft',
    reapply_events = {
      enabled = true,
      events = {
        'ColorScheme',
      },
    },
  },
  dynamic = {
    interval_ms = 80,
  },
  keymaps = {
    preview = {
      lhs = 'z',
      mode = 'n',
      opts = {
        desc = 'hlcraft flash current highlight',
        silent = true,
        nowait = true,
      },
    },
  },
})
```

For option details and recipes, see [Configuration](./docs/en/configuration.md).

## Persistence

Saved overrides are written under `persistence.dir` as TOML files. Each file stores one top-level section, and each highlight entry stores only the override fields you choose to keep.

Dynamic color settings are stored directly in each highlight entry's `dynamic` table. See [Dynamic Colors](./docs/en/dynamic-colors.md) and [Persistence](./docs/en/persistence.md) for the full model.

## Health Check

Run:

```vim
:checkhealth hlcraft
```

The health check verifies Neovim compatibility, persistence directory access, write support, and TOML parse integrity.
