# Dynamic Colors

[Index](./index.md) | [中文](../zh/dynamic-colors.md)

Dynamic colors let a highlight channel keep changing after an override has been applied. Instead of saving one static `fg`, `bg`, or `sp`, hlcraft stores a declarative model that can be sampled over time.

## What It Can Do

Dynamic colors are good for:

- Gentle pulse and breathing effects.
- Hue shifts.
- Gradients over time.
- Blink-style emphasis.
- Brightness and saturation transforms.
- Per-channel animation for `fg`, `bg`, and `sp`.

## TUI Boundaries

Dynamic colors run inside the Neovim TUI highlight system. That means:

- The runtime updates highlight group color values over time.
- The effect is group-level, not per character.
- There is no spatial gradient across the terminal grid.
- There is no independent animation timeline per rendered cell.
- Smoothness is limited by `dynamic.interval_ms`, terminal rendering, and colorscheme complexity.

This keeps the feature predictable and portable across terminal environments.

## Presets

hlcraft includes these preset names:

- `pulse`
- `breath`
- `hue`
- `gradient`
- `blink`
- `duotone`

Presets are starting points. They are stored using the same declarative model as custom dynamic colors, so a preset can be edited further in the raw JSON editor.

## Editing Workflow

Dynamic colors are edited from `FG`, `BG`, and `SP` color editors:

- Press `d` to toggle dynamic mode for the current channel.
- Press `m` to cycle presets.
- Press `+` or `-` to adjust duration, or phase when the phase row is selected.
- Press `e` to open the raw JSON editor.
- Save from the detail view when the result is ready.

The workspace shows animated color swatches as the primary preview. Compact text such as `pulse 2000ms` remains visible as metadata and fallback.

## Declarative Model

A dynamic channel is a table with required `version` and `timeline` fields:

```json
{
  "version": 1,
  "preset": "pulse",
  "duration": 2000,
  "loop": "pingpong",
  "phase": 0,
  "interpolation": "smooth",
  "timeline": [
    { "at": 0, "color": "base" },
    { "at": 1, "color": "#ff6699" }
  ],
  "transforms": [
    {
      "type": "brightness",
      "interpolation": "sine",
      "timeline": [
        { "at": 0, "value": 0.8 },
        { "at": 1, "value": 1.2 }
      ]
    }
  ]
}
```

Fields:

- `version`: currently `1`.
- `preset`: optional label for the preset or custom shape.
- `duration`: animation duration in milliseconds.
- `loop`: `repeat`, `pingpong`, or `once`.
- `phase`: offset from `0` to `1`.
- `interpolation`: color interpolation mode.
- `timeline`: non-empty list of color stops.
- `transforms`: optional list of numeric transforms.

## Timeline Stops

Color stops use:

```json
{ "at": 0.5, "color": "#88ccff" }
```

`at` must be between `0` and `1`.

`color` can be:

- `base`: the channel's non-dynamic base color.
- `fg`, `bg`, or `sp`: another resolved color channel.
- A concrete color such as `#88ccff`.

## Transforms

Transforms use:

```json
{
  "type": "brightness",
  "timeline": [
    { "at": 0, "value": 0.8 },
    { "at": 1, "value": 1.2 }
  ]
}
```

Supported transform types:

- `brightness`
- `hue_shift`
- `saturation`

Transforms are sampled after the base timeline color is sampled.

## Persistence

Dynamic settings are stored directly in the entry's `dynamic` table:

```toml
["demo.group"]
"Normal" = { fg = "#d7d7ff", dynamic = { fg = { version = 1, preset = "pulse", duration = 2000, loop = "pingpong", interpolation = "smooth", timeline = [{ at = 0, color = "base" }, { at = 1, color = "#ff6699" }] } } }
```

See [Persistence](./persistence.md) for the full TOML model.
