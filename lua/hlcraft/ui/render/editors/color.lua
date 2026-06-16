local ui_fields = require('hlcraft.ui.fields')
local render_util = require('hlcraft.render.util')
local session = require('hlcraft.ui.session')
local detail_menu = require('hlcraft.ui.render.detail_menu')

local M = {}

local function append_editor_row(lines, geometry, key, text)
  local row = {
    line = #lines + 1,
    key = key,
  }
  geometry.editor_rows[key] = row
  lines[#lines + 1] = text
  return row
end

function M.build(instance, geometry, result, field, width, line_offset)
  local label = ui_fields.detail_labels[field] or field:upper()
  local fallback = detail_menu.fallback_value(result, field)
  local value = session.display_value(result.name, field, fallback)
  local display_value = detail_menu.display_text(value)
  local sample = 'The quick brown fox jumps over hlcraft.'

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
    'Keys: r/R g/G b/B adjust, n NONE, i input, d dynamic, s save, q back'
  )

  for index, line in ipairs(lines) do
    lines[index] = render_util.truncate(line, width)
  end
  return lines
end

return M
