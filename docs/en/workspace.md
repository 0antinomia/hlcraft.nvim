# Workspace

[Index](./index.md) | [中文](../zh/workspace.md)

The hlcraft workspace is the interactive control surface for highlight search, inspection, editing, previewing, and saving.

Open it with:

```vim
:Hlcraft
```

## Layout

The workspace is organized around three activities:

- Search: narrow the highlight list by name or color.
- Inspect: read the selected highlight's resolved values, source, links, and current overrides.
- Edit: change group, color, style, blend, or dynamic color settings.

## Search

The top area contains two inputs:

- `name`: case-insensitive substring match on highlight group names.
- `color`: color similarity search.

The filters can be combined.

Color queries accept:

- `#RRGGBB`
- `NONE`

`NONE` matches groups whose resolved color is unset. By default this checks `fg` and `bg`; enable `search.include_sp` to include `sp`.

## Detail View

The detail view shows the selected highlight group and the values hlcraft can reason about:

- Resolved `fg`, `bg`, and `sp`.
- Style flags such as `bold`, `italic`, and underline variants.
- Blend value.
- Link chain and resolved target.
- Draft and persisted override state.
- Persistence group.

The detail view is designed for repeated edits: change one field, see it applied immediately, and save only when the result is worth keeping.

## Editors

Each editable field has a focused editor:

- Group editor: choose or create the TOML section where the override will be saved.
- Color editor: set, clear, preview, or make a color channel dynamic.
- Style editor: toggle boolean style attributes.
- Blend editor: set or clear blend.
- Dynamic editor: adjust preset, duration, phase, and raw JSON for dynamic channels.

Invalid input is rejected before it mutates draft state.

## Preview Key

The preview key flashes the currently selected highlight group so you can identify it in the live UI.

The default is:

```lua
keymaps = {
  preview = {
    lhs = 'z',
    mode = 'n',
  },
}
```

The mapping exists only while the workspace is open. It is global during that time so it still works after switching windows.

## Save And Discard

Draft overrides are applied immediately. Persisted overrides are written only when you save.

Use the save action when you want the current draft for a highlight group to survive restart or colorscheme changes. Use discard/restore actions when you want to go back to the persisted state.

## TUI Boundaries

hlcraft runs inside Neovim's terminal UI. It can preview group-level highlight changes and animated color swatches, but it cannot provide pixel-level animation, spatial gradients across characters, or per-character motion effects. Dynamic colors are applied by updating highlight group values over time.
