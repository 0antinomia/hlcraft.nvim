# hlcraft.nvim Documentation

[中文](../zh/index.md)

`hlcraft.nvim` is an interactive highlight workbench for Neovim. It lets you inspect highlight groups, search by name or color, edit overrides, preview the result, and persist your final decisions as TOML files.

The plugin can be used as a practical highlight editor, or as a personal theme-building layer on top of any colorscheme. The stored result belongs to you: plain TOML, readable by humans, and replayed by hlcraft when Neovim starts or when configured events fire.

## Start Here

- [Configuration](./configuration.md): setup options, defaults, validation rules, and common recipes.
- [Workspace](./workspace.md): the interactive UI, search behavior, editors, and keymaps.
- [Dynamic Colors](./dynamic-colors.md): presets, custom JSON, runtime limits, and the declarative model.
- [Persistence](./persistence.md): TOML layout, groups, reload behavior, and manual editing.
- [Architecture](./architecture.md): project structure and module responsibilities.

## Core Ideas

hlcraft separates three concerns:

- Live Neovim highlight state, read from the current editor session.
- Draft overrides, edited interactively and applied immediately.
- Persisted overrides, stored in TOML and replayed later.

This means you can explore without committing every change. Save only the overrides you want to keep.

## Minimal Setup

```lua
require('hlcraft').setup()
```

Open the workbench:

```vim
:Hlcraft
```
