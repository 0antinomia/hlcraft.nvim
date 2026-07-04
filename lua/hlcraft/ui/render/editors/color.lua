local ui_fields = require('hlcraft.ui.fields')
local field_values = require('hlcraft.ui.field_values')
local session = require('hlcraft.ui.session')
local editor_layout = require('hlcraft.ui.render.editor_layout')
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
  return editor_layout.finish(lines, width, hints.color(width))
end

return M
