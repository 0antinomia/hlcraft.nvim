local ui_fields = require('hlcraft.ui.fields')
local render_util = require('hlcraft.render.util')
local detail_values = require('hlcraft.ui.state.detail_values')
local overrides = require('hlcraft.overrides')
local detail_menu = require('hlcraft.ui.render.detail_menu')
local dynamic_model = require('hlcraft.dynamic.model')
local dynamic_preview = require('hlcraft.ui.dynamic_preview')

local M = {}

local function swatch_end_col(col_start, swatch)
  return col_start + vim.fn.strdisplaywidth(swatch)
end

local function append_editor_row(lines, geometry, key, text)
  local row = {
    line = #lines + 1,
    key = key,
  }
  geometry.editor_rows[key] = row
  lines[#lines + 1] = text
  return row
end

local function build_color_editor_lines(instance, geometry, result, field, width, line_offset)
  local label = ui_fields.detail_labels[field] or field:upper()
  local fallback = detail_menu.fallback_value(result, field)
  local value = detail_values.display_value(result.name, field, fallback)
  local display_value = detail_menu.display_text(value)
  local sample = 'The quick brown fox jumps over hlcraft.'
  local dynamic = dynamic_model.channel_set[field] and detail_values.dynamic_value(result.name, field) or nil

  if dynamic then
    local swatch = '████████████'
    local lines = {
      ('Color editor: %s'):format(label),
      string.rep('─', math.max(20, math.min(width, 36))),
      'Mode: dynamic',
      ('Effect: %s'):format(dynamic.mode),
      ('Speed: %dms'):format(dynamic.speed),
      ('Swatch: %s'):format(swatch),
    }

    dynamic_preview.register(instance, {
      line = 6 + line_offset,
      col_start = 8,
      col_end = swatch_end_col(8, swatch),
      text = swatch,
      field = field,
      base = fallback,
      dynamic = dynamic,
    })
    if dynamic.mode == 'rgb' then
      for index, palette_color in ipairs(dynamic.palette or dynamic_model.default_palette()) do
        local prefix = ('Palette %d: '):format(index)
        local row = append_editor_row(
          lines,
          geometry,
          ('dynamic_palette:%d'):format(index),
          ('%s%s %s'):format(prefix, ui_fields.dynamic_palette_swatch, palette_color)
        )
        local col_start = vim.fn.strdisplaywidth(prefix)
        dynamic_preview.register(instance, {
          line = row.line + line_offset,
          col_start = col_start,
          col_end = swatch_end_col(col_start, ui_fields.dynamic_palette_swatch),
          text = ui_fields.dynamic_palette_swatch,
          field = field,
          base = palette_color,
          dynamic = {
            mode = 'rgb',
            speed = dynamic.speed,
            palette = { palette_color, palette_color },
          },
        })
      end
      append_editor_row(
        lines,
        geometry,
        'dynamic_keys',
        'Keys: m mode, -/+ speed, [/] palette, a add, x delete, i input, d static, s save, q back'
      )
    else
      append_editor_row(lines, geometry, 'dynamic_keys', 'Keys: m mode, -/+ speed, d static, s save, q back')
    end

    for index, line in ipairs(lines) do
      lines[index] = render_util.truncate(line, width)
    end
    return lines
  end

  local lines = {
    ('Color editor: %s'):format(label),
    string.rep('─', math.max(20, math.min(width, 36))),
    'Mode: static',
    ('Current: %s'):format(display_value),
    ('Sample: %s'):format(sample),
    ('Swatch: %s'):format(display_value),
  }

  geometry.color_sample = {
    line = 5,
    text = sample,
    value = value,
    field = field,
  }
  geometry.color_swatch = {
    line = 6,
    text = display_value,
    value = value,
    field = field,
  }
  append_editor_row(
    lines,
    geometry,
    'color_keys',
    ('Keys: r/R red -/+%d, g/G green -/+%d, b/B blue -/+%d, n NONE, i input, d dynamic, s save, q back'):format(
      ui_fields.color_step,
      ui_fields.color_step,
      ui_fields.color_step
    )
  )

  for index, line in ipairs(lines) do
    lines[index] = render_util.truncate(line, width)
  end
  return lines
end

local function build_group_editor_lines(geometry, result, width)
  local lines = {
    ('Group editor: %s'):format(result.name),
    string.rep('─', math.max(20, math.min(width, 36))),
  }

  for _, group_name in ipairs(overrides.known_groups()) do
    append_editor_row(lines, geometry, 'group:' .. group_name, group_name)
  end
  append_editor_row(lines, geometry, 'new_group', '+ New group (i)')

  for index, line in ipairs(lines) do
    lines[index] = render_util.truncate(line, width)
  end
  return lines
end

local function build_blend_editor_lines(geometry, result, width)
  local fallback = detail_menu.fallback_value(result, 'blend')
  local value = detail_values.display_value(result.name, 'blend', fallback)
  local lines = {
    'Blend editor',
    string.rep('─', math.max(20, math.min(width, 36))),
    ('Current: %s'):format(detail_menu.display_text(value)),
  }
  append_editor_row(
    lines,
    geometry,
    'blend_keys',
    ('Keys: -/+ by %d, </> by %d, u unset, i input, s save, q back'):format(
      ui_fields.blend_small_step,
      ui_fields.blend_large_step
    )
  )

  for index, line in ipairs(lines) do
    lines[index] = render_util.truncate(line, width)
  end
  return lines
end

local function normalize_build_args(instance, geometry, result, field, width, line_offset)
  if line_offset ~= nil or width ~= nil then
    return instance, geometry, result, field, width, line_offset or 0
  end

  return nil, instance, geometry, result, field, 0
end

function M.build(instance, geometry, result, field, width, line_offset)
  instance, geometry, result, field, width, line_offset =
    normalize_build_args(instance, geometry, result, field, width, line_offset)
  if field == 'fg' or field == 'bg' or field == 'sp' then
    return build_color_editor_lines(instance, geometry, result, field, width, line_offset)
  end
  if field == 'group' then
    return build_group_editor_lines(geometry, result, width)
  end
  if field == 'blend' then
    return build_blend_editor_lines(geometry, result, width)
  end
  return nil
end

return M
