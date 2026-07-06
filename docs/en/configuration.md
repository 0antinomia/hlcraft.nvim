# Configuration

[Index](./index.md) | [中文](../zh/configuration.md)

hlcraft uses a declarative configuration schema. Unknown keys are rejected, nested option groups are validated, and values are normalized before the plugin is initialized.

## Default Configuration

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

## `transparent`

Controls whether hlcraft applies a transparent baseline before draft and persisted overrides.

```lua
transparent = {
  enabled = false,
  scope = 'extended',
}
```

- `enabled`: enables or disables the transparent baseline.
- `scope = 'core'`: clears foundational groups such as `Normal`, `NormalFloat`, and `SignColumn`.
- `scope = 'extended'`: also clears a wider set of UI groups such as popup menu and winbar-related highlights.

Use this when you want hlcraft to maintain transparency as part of your final highlight layer.

## `search`

Controls color search and input update cadence.

```lua
search = {
  threshold = 100,
  include_sp = false,
  debounce_ms = 100,
}
```

- `threshold`: RGB Euclidean distance threshold for color search. Must be finite and between `0` and `1000`.
- `include_sp`: includes the `sp` channel in color matching.
- `debounce_ms`: delay before search inputs update results. Use `0` for immediate updates.

Lower thresholds produce stricter color matches. Higher thresholds return broader result sets.

## `persistence`

Controls where TOML files are stored and when persisted overrides are replayed.

```lua
persistence = {
  dir = vim.fn.stdpath('config') .. '/hlcraft',
  reapply_events = {
    enabled = true,
    events = {
      'ColorScheme',
    },
  },
}
```

`persistence.dir` is intentionally visible by default. The files are part of your Neovim configuration, not hidden cache data.

Structured reapply events are also supported:

```lua
persistence = {
  reapply_events = {
    enabled = true,
    events = {
      'ColorScheme',
      { event = 'SessionLoadPost', once = false },
    },
  },
}
```

Each structured entry supports:

- `event`: autocmd event name.
- `pattern`: optional autocmd pattern.
- `once`: whether the autocmd runs only once.

Set `persistence.reapply_events.enabled = false` to disable automatic replay.

## `dynamic`

Controls the runtime cadence for dynamic color overrides.

```lua
dynamic = {
  interval_ms = 80,
}
```

`interval_ms` must be finite and between `16` and `1000`. Lower values feel smoother but write highlight groups more often.

Dynamic color behavior is documented in [Dynamic Colors](./dynamic-colors.md).

## `keymaps.preview`

Controls the temporary key used to flash the currently selected highlight group.

```lua
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
}
```

The keymap is global while the hlcraft workspace is open, and is removed when the workspace closes. Set `keymaps.preview = false` to disable it.

`mode` is currently limited to normal mode (`'n'`). `opts` accepts `desc`, `silent`, and `nowait`.

## Example: Personal Defaults

```lua
require('hlcraft').setup({
  transparent = {
    enabled = true,
    scope = 'extended',
  },
  search = {
    threshold = 80,
    debounce_ms = 0,
  },
  dynamic = {
    interval_ms = 100,
  },
  keymaps = {
    preview = {
      lhs = '<leader>hp',
      mode = 'n',
      opts = {
        desc = 'hlcraft preview highlight',
        silent = true,
        nowait = true,
      },
    },
  },
})
```
