local field_values = require('hlcraft.ui.field_values')
local session = require('hlcraft.ui.session')
local editor_layout = require('hlcraft.ui.render.editor_layout')
local hints = require('hlcraft.ui.render.hints')

local M = {}

function M.build(geometry, result, width)
  local fallback = field_values.fallback_value(result, 'blend')
  local value = session.display_value(result.name, 'blend', fallback)
  local lines = {
    'Blend editor',
    string.rep('─', math.max(20, math.min(width, 36))),
    ('Current: %s'):format(field_values.display_text(value)),
  }
  return editor_layout.finish(lines, width, hints.blend(width))
end

return M
