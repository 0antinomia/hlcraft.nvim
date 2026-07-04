local ui_fields = require('hlcraft.ui.fields')
local field_values = require('hlcraft.ui.field_values')
local render_util = require('hlcraft.render.util')
local session = require('hlcraft.ui.session')
local hints = require('hlcraft.ui.render.hints')

local M = {}

function M.build(instance, geometry, result, field, width, line_offset)
  local label = ui_fields.detail_labels[field] or field:upper()
  local fallback = field_values.fallback_value(result, field)
  local value = session.display_value(result.name, field, fallback)
  local display_value = field_values.display_text(value)
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
  lines[#lines + 1] = ''
  for _, line in ipairs(hints.color()) do
    lines[#lines + 1] = line
  end

  for index, line in ipairs(lines) do
    lines[index] = render_util.truncate(line, width)
  end
  return lines
end

return M
