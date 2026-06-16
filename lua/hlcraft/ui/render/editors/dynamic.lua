local ui_fields = require('hlcraft.ui.fields')
local render_util = require('hlcraft.render.util')
local dynamic_model = require('hlcraft.dynamic.model')
local dynamic_preview = require('hlcraft.ui.dynamic_preview')
local detail_menu = require('hlcraft.ui.render.detail_menu')

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

function M.build(instance, geometry, result, field, width, line_offset, dynamic)
  local label = ui_fields.detail_labels[field] or field:upper()
  local fallback = detail_menu.fallback_value(result, field)
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
  elseif dynamic.mode == 'breath' then
    local params = dynamic_model.normalize_params('breath', dynamic.params)
    append_editor_row(lines, geometry, 'dynamic_param:min', ('Min: %.2f'):format(params.min))
    append_editor_row(lines, geometry, 'dynamic_param:max', ('Max: %.2f'):format(params.max))
  end
  append_editor_row(
    lines,
    geometry,
    'dynamic_keys',
    'Keys: m mode, -/+ speed/param, [/] palette, a add, x delete, i input, d static, s save, q back'
  )

  for index, line in ipairs(lines) do
    if geometry.editor_rows.dynamic_keys and geometry.editor_rows.dynamic_keys.line == index then
      lines[index] = line
    else
      lines[index] = render_util.truncate(line, width)
    end
  end
  return lines
end

return M
